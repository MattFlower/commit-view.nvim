local M = {}

--- Parse a unified diff hunk header
---@param header string e.g. "@@ -10,5 +12,7 @@ optional context"
---@return table|nil { old_start, old_count, new_start, new_count, context }
local function parse_hunk_header(header)
  local old_start, old_count, new_start, new_count =
    header:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")

  if not old_start then
    return nil
  end

  return {
    old_start = tonumber(old_start),
    old_count = tonumber(old_count) or 1,
    new_start = tonumber(new_start),
    new_count = tonumber(new_count) or 1,
    context = header:match("@@ .+ @@(.*)$") or "",
  }
end

--- Parse unified diff output into structured hunk objects
---@param diff_lines string[] raw output from `git diff`
---@return table hunks list of hunk objects
---@return table|nil header diff header lines (diff --git, ---, +++)
function M.parse(diff_lines)
  local hunks = {}
  local header_lines = {}
  local current_hunk = nil
  local in_header = true

  for i, line in ipairs(diff_lines) do
    if line:match("^@@") then
      -- Start of a new hunk
      in_header = false

      -- Save previous hunk
      if current_hunk then
        current_hunk.end_line = i - 1
        table.insert(hunks, current_hunk)
      end

      local parsed = parse_hunk_header(line)
      if parsed then
        current_hunk = {
          header = line,
          old_start = parsed.old_start,
          old_count = parsed.old_count,
          new_start = parsed.new_start,
          new_count = parsed.new_count,
          context = parsed.context,
          lines = {},
          start_line = i,  -- line number in the diff output
          end_line = nil,
        }
      end
    elseif in_header then
      table.insert(header_lines, line)
    elseif current_hunk then
      table.insert(current_hunk.lines, line)
    end
  end

  -- Save last hunk
  if current_hunk then
    current_hunk.end_line = #diff_lines
    table.insert(hunks, current_hunk)
  end

  return hunks, #header_lines > 0 and header_lines or nil
end

--- Find which hunk contains a given line number in the new file
---@param hunks table[] parsed hunks
---@param line_nr integer 1-based line number in the new file
---@return integer|nil hunk_index
function M.find_hunk_at_line(hunks, line_nr)
  for i, hunk in ipairs(hunks) do
    local hunk_end = hunk.new_start + hunk.new_count - 1
    if line_nr >= hunk.new_start and line_nr <= hunk_end then
      return i
    end
  end
  return nil
end

--- Get the line ranges for each hunk in the new file (for sign placement)
---@param hunks table[] parsed hunks
---@return table[] { { start_line, end_line, hunk_index } }
function M.get_hunk_ranges(hunks)
  local ranges = {}
  for i, hunk in ipairs(hunks) do
    table.insert(ranges, {
      start_line = hunk.new_start,
      end_line = hunk.new_start + math.max(hunk.new_count - 1, 0),
      hunk_index = i,
    })
  end
  return ranges
end

return M
