local Job = require("plenary.job")

local M = {}

--- Status code to human-readable type
local status_map = {
  M = "modified",
  A = "added",
  D = "deleted",
  R = "renamed",
  C = "copied",
  U = "unmerged",
  ["?"] = "untracked",
  ["!"] = "ignored",
}

--- Parse a single line of `git status --porcelain` output
---@param line string
---@return table|nil
local function parse_status_line(line)
  if #line < 4 then
    return nil
  end

  local index_status = line:sub(1, 1)
  local worktree_status = line:sub(2, 2)
  local filepath = line:sub(4)

  -- Handle renames: "R  old -> new"
  local rename_target = nil
  if index_status == "R" or worktree_status == "R" then
    local arrow_pos = filepath:find(" -> ")
    if arrow_pos then
      rename_target = filepath:sub(arrow_pos + 4)
      filepath = filepath:sub(1, arrow_pos - 1)
    end
  end

  -- Skip ignored files
  if index_status == "!" then
    return nil
  end

  -- Determine which section(s) this file belongs to
  local entries = {}

  if index_status == "?" and worktree_status == "?" then
    -- Untracked file
    table.insert(entries, {
      filepath = filepath,
      rename_target = rename_target,
      status = "?",
      status_type = "untracked",
      section = "untracked",
    })
  else
    -- Check for staged changes (index column)
    if index_status ~= " " and index_status ~= "?" then
      table.insert(entries, {
        filepath = rename_target or filepath,
        original_path = rename_target and filepath or nil,
        status = index_status,
        status_type = status_map[index_status] or "unknown",
        section = "staged",
      })
    end

    -- Check for unstaged changes (worktree column)
    if worktree_status ~= " " and worktree_status ~= "?" then
      table.insert(entries, {
        filepath = rename_target or filepath,
        original_path = rename_target and filepath or nil,
        status = worktree_status,
        status_type = status_map[worktree_status] or "unknown",
        section = "unstaged",
      })
    end
  end

  return entries
end

--- Get git status for the repository
---@param git_root string
---@param callback fun(files: table|nil, err: string|nil)
function M.get_status(git_root, callback)
  Job:new({
    command = "git",
    args = { "-C", git_root, "status", "--porcelain", "-uall" },
    on_exit = vim.schedule_wrap(function(j, code)
      if code ~= 0 then
        callback(nil, "git status failed: " .. table.concat(j:stderr_result(), "\n"))
        return
      end

      local files = {}
      for _, line in ipairs(j:result()) do
        local entries = parse_status_line(line)
        if entries then
          for _, entry in ipairs(entries) do
            table.insert(files, entry)
          end
        end
      end

      callback(files)
    end),
  }):start()
end

--- Synchronous version for simpler cases
---@param git_root string
---@return table files, string|nil err
function M.get_status_sync(git_root)
  local output = vim.fn.systemlist({ "git", "-C", git_root, "status", "--porcelain", "-uall" })
  if vim.v.shell_error ~= 0 then
    return {}, "git status failed"
  end

  local files = {}
  for _, line in ipairs(output) do
    local entries = parse_status_line(line)
    if entries then
      for _, entry in ipairs(entries) do
        table.insert(files, entry)
      end
    end
  end

  return files
end

return M
