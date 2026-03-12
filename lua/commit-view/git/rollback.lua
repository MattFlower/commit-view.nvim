local Job = require("plenary.job")

local M = {}

--- Rollback all changes in a file (git checkout --)
---@param git_root string
---@param filepath string
---@param callback fun(success: boolean)
function M.rollback_file(git_root, filepath, callback)
  Job:new({
    command = "git",
    args = { "-C", git_root, "checkout", "--", filepath },
    on_exit = vim.schedule_wrap(function(j, code)
      if code ~= 0 then
        local stderr = table.concat(j:stderr_result(), "\n")
        vim.notify("Rollback failed: " .. stderr, vim.log.levels.ERROR)
      end
      callback(code == 0)
    end),
  }):start()
end

--- Rollback a single hunk (apply reverse patch to working tree)
---@param git_root string
---@param patch_content string valid unified diff patch for the hunk
---@param callback fun(success: boolean)
function M.rollback_hunk(git_root, patch_content, callback)
  Job:new({
    command = "git",
    args = { "-C", git_root, "apply", "--reverse", "--unidiff-zero", "-" },
    writer = patch_content,
    on_exit = vim.schedule_wrap(function(j, code)
      if code ~= 0 then
        local stderr = table.concat(j:stderr_result(), "\n")
        vim.notify("Hunk rollback failed: " .. stderr, vim.log.levels.ERROR)
      end
      callback(code == 0)
    end),
  }):start()
end

return M
