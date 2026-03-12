local Job = require("plenary.job")

local M = {}

--- Get the last commit message (for amend mode)
---@param git_root string
---@param callback fun(message: string|nil)
function M.get_last_message(git_root, callback)
  Job:new({
    command = "git",
    args = { "-C", git_root, "log", "-1", "--format=%B" },
    on_exit = vim.schedule_wrap(function(j, code)
      if code ~= 0 then
        callback(nil)
        return
      end
      local lines = j:result()
      -- Trim trailing empty lines
      while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
      end
      callback(table.concat(lines, "\n"))
    end),
  }):start()
end

--- Stage selected files and commit
---@param git_root string
---@param filepaths string[] files to stage before committing
---@param message string commit message
---@param amend boolean whether to amend the previous commit
---@param callback fun(success: boolean, output: string)
function M.commit(git_root, filepaths, message, amend, callback)
  -- First stage the selected files
  local stage = require("commit-view.git.stage")
  stage.stage_files(git_root, filepaths, function(stage_ok)
    if not stage_ok then
      callback(false, "Failed to stage files")
      return
    end

    -- Build commit args
    local args = { "-C", git_root, "commit" }
    if amend then
      table.insert(args, "--amend")
    end
    if message and message ~= "" then
      table.insert(args, "-m")
      table.insert(args, message)
    elseif amend then
      table.insert(args, "--no-edit")
    end

    Job:new({
      command = "git",
      args = args,
      on_exit = vim.schedule_wrap(function(j, code)
        if code ~= 0 then
          local stderr = table.concat(j:stderr_result(), "\n")
          callback(false, stderr)
        else
          local stdout = table.concat(j:result(), "\n")
          callback(true, stdout)
        end
      end),
    }):start()
  end)
end

--- Push to remote
---@param git_root string
---@param callback fun(success: boolean, output: string)
function M.push(git_root, callback)
  Job:new({
    command = "git",
    args = { "-C", git_root, "push" },
    on_exit = vim.schedule_wrap(function(j, code)
      if code ~= 0 then
        local stderr = table.concat(j:stderr_result(), "\n")
        callback(false, stderr)
      else
        local stdout = table.concat(j:result(), "\n")
        callback(true, stdout)
      end
    end),
  }):start()
end

return M
