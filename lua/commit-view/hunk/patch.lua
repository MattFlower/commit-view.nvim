local M = {}

--- Generate a valid git patch for a single hunk
---@param filepath string relative path from git root
---@param hunk table parsed hunk object from parser.lua
---@param header_lines string[]|nil diff header lines (diff --git, ---, +++)
---@return string patch content suitable for `git apply`
function M.make_patch(filepath, hunk, header_lines)
  local lines = {}

  if header_lines and #header_lines > 0 then
    for _, line in ipairs(header_lines) do
      table.insert(lines, line)
    end
  else
    -- Generate minimal diff header
    table.insert(lines, "diff --git a/" .. filepath .. " b/" .. filepath)
    table.insert(lines, "--- a/" .. filepath)
    table.insert(lines, "+++ b/" .. filepath)
  end

  -- Add the hunk header
  table.insert(lines, hunk.header)

  -- Add hunk lines
  for _, line in ipairs(hunk.lines) do
    table.insert(lines, line)
  end

  -- Ensure trailing newline
  local result = table.concat(lines, "\n")
  if not result:match("\n$") then
    result = result .. "\n"
  end

  return result
end

--- Generate a reverse patch for a hunk (for rollback)
--- This swaps +/- lines and adjusts the header
---@param filepath string
---@param hunk table parsed hunk object
---@param header_lines string[]|nil diff header lines
---@return string reverse patch content
function M.make_reverse_patch(filepath, hunk, header_lines)
  local lines = {}

  if header_lines and #header_lines > 0 then
    for _, line in ipairs(header_lines) do
      -- Swap a/ and b/ in the header for reverse
      if line:match("^%-%-%- a/") then
        table.insert(lines, line:gsub("^%-%-%- a/", "--- b/"))
      elseif line:match("^%+%+%+ b/") then
        table.insert(lines, line:gsub("^%+%+%+ b/", "+++ a/"))
      else
        table.insert(lines, line)
      end
    end
  else
    table.insert(lines, "diff --git a/" .. filepath .. " b/" .. filepath)
    table.insert(lines, "--- a/" .. filepath)
    table.insert(lines, "+++ b/" .. filepath)
  end

  -- Reverse the hunk header (swap old/new)
  local reversed_header = string.format(
    "@@ -%d,%d +%d,%d @@%s",
    hunk.new_start, hunk.new_count,
    hunk.old_start, hunk.old_count,
    hunk.context or ""
  )
  table.insert(lines, reversed_header)

  -- Reverse the hunk lines (swap + and -)
  for _, line in ipairs(hunk.lines) do
    if line:sub(1, 1) == "+" then
      table.insert(lines, "-" .. line:sub(2))
    elseif line:sub(1, 1) == "-" then
      table.insert(lines, "+" .. line:sub(2))
    else
      table.insert(lines, line)
    end
  end

  local result = table.concat(lines, "\n")
  if not result:match("\n$") then
    result = result .. "\n"
  end

  return result
end

return M
