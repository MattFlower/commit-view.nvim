local Job = require("plenary.job")

local M = {}

--- Stage a file (git add)
---@param git_root string
---@param filepath string
---@param callback fun(success: boolean)
function M.stage_file(git_root, filepath, callback)
  Job:new({
    command = "git",
    args = { "-C", git_root, "add", "--", filepath },
    on_exit = vim.schedule_wrap(function(_, code)
      callback(code == 0)
    end),
  }):start()
end

--- Unstage a file (git reset HEAD)
---@param git_root string
---@param filepath string
---@param callback fun(success: boolean)
function M.unstage_file(git_root, filepath, callback)
  Job:new({
    command = "git",
    args = { "-C", git_root, "reset", "HEAD", "--", filepath },
    on_exit = vim.schedule_wrap(function(_, code)
      callback(code == 0)
    end),
  }):start()
end

--- Stage multiple files
---@param git_root string
---@param filepaths string[]
---@param callback fun(success: boolean)
function M.stage_files(git_root, filepaths, callback)
  if #filepaths == 0 then
    callback(true)
    return
  end

  local args = { "-C", git_root, "add", "--" }
  for _, fp in ipairs(filepaths) do
    table.insert(args, fp)
  end

  Job:new({
    command = "git",
    args = args,
    on_exit = vim.schedule_wrap(function(_, code)
      callback(code == 0)
    end),
  }):start()
end

--- Stage a single hunk via git apply --cached
---@param git_root string
---@param patch_content string valid unified diff patch
---@param callback fun(success: boolean)
function M.stage_hunk(git_root, patch_content, callback)
  Job:new({
    command = "git",
    args = { "-C", git_root, "apply", "--cached", "--unidiff-zero", "-" },
    writer = patch_content,
    on_exit = vim.schedule_wrap(function(j, code)
      if code ~= 0 then
        local stderr = table.concat(j:stderr_result(), "\n")
        vim.notify("Stage hunk failed: " .. stderr, vim.log.levels.ERROR)
      end
      callback(code == 0)
    end),
  }):start()
end

--- Unstage a single hunk via git apply --cached --reverse
---@param git_root string
---@param patch_content string valid unified diff patch
---@param callback fun(success: boolean)
function M.unstage_hunk(git_root, patch_content, callback)
  Job:new({
    command = "git",
    args = { "-C", git_root, "apply", "--cached", "--reverse", "--unidiff-zero", "-" },
    writer = patch_content,
    on_exit = vim.schedule_wrap(function(j, code)
      if code ~= 0 then
        local stderr = table.concat(j:stderr_result(), "\n")
        vim.notify("Unstage hunk failed: " .. stderr, vim.log.levels.ERROR)
      end
      callback(code == 0)
    end),
  }):start()
end

return M
