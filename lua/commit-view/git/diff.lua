local Job = require("plenary.job")

local M = {}

--- Get unified diff for a file
---@param git_root string
---@param filepath string
---@param staged boolean whether to show staged (--cached) diff
---@param callback fun(lines: string[])
function M.get_diff(git_root, filepath, staged, callback)
  local args = { "-C", git_root, "diff", "--no-color" }
  if staged then
    table.insert(args, "--cached")
  end
  table.insert(args, "--")
  table.insert(args, filepath)

  Job:new({
    command = "git",
    args = args,
    on_exit = vim.schedule_wrap(function(j, _)
      callback(j:result())
    end),
  }):start()
end

--- Get file content at a specific revision
---@param git_root string
---@param rev string e.g. "HEAD", "" (index/staging area)
---@param filepath string
---@param callback fun(lines: string[]|nil, err: string|nil)
function M.show(git_root, rev, filepath, callback)
  local ref = rev .. ":" .. filepath
  Job:new({
    command = "git",
    args = { "-C", git_root, "show", ref },
    on_exit = vim.schedule_wrap(function(j, code)
      if code ~= 0 then
        callback(nil, "git show failed for " .. ref)
        return
      end
      callback(j:result())
    end),
  }):start()
end

--- Get file content at HEAD (synchronous, for simpler cases)
---@param git_root string
---@param filepath string
---@return string[]|nil lines
function M.show_head_sync(git_root, filepath)
  local output = vim.fn.systemlist({ "git", "-C", git_root, "show", "HEAD:" .. filepath })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return output
end

--- Read working tree file content
---@param git_root string
---@param filepath string
---@return string[]|nil lines
function M.read_working_file(git_root, filepath)
  local full_path = git_root .. "/" .. filepath
  if vim.fn.filereadable(full_path) == 0 then
    return nil
  end
  return vim.fn.readfile(full_path)
end

return M
