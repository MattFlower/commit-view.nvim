local state = require("commit-view.state")
local parser = require("commit-view.hunk.parser")
local patch = require("commit-view.hunk.patch")
local git_diff = require("commit-view.git.diff")

local M = {}

-- Per-file hunk selection state: { [filepath] = { hunks = {}, header = {}, selected = {} } }
local hunk_state = {}

--- Load and parse hunks for a file
---@param filepath string
---@param section string "staged"|"unstaged"
---@param callback fun(hunks: table[], header: string[]|nil)
function M.load_hunks(filepath, section, callback)
  local s = state.get()
  local staged = (section == "staged")

  git_diff.get_diff(s.git_root, filepath, staged, function(diff_lines)
    local hunks, header = parser.parse(diff_lines)
    hunk_state[filepath] = {
      hunks = hunks,
      header = header,
      selected = {},
    }
    callback(hunks, header)
  end)
end

--- Get cached hunks for a file (synchronous)
---@param filepath string
---@return table|nil
function M.get_file_state(filepath)
  return hunk_state[filepath]
end

--- Toggle hunk selection
---@param filepath string
---@param hunk_index integer
function M.toggle(filepath, hunk_index)
  local fs = hunk_state[filepath]
  if not fs then return end

  if fs.selected[hunk_index] then
    fs.selected[hunk_index] = nil
  else
    fs.selected[hunk_index] = true
  end
end

--- Check if a hunk is selected
---@param filepath string
---@param hunk_index integer
---@return boolean
function M.is_selected(filepath, hunk_index)
  local fs = hunk_state[filepath]
  if not fs then return false end
  return fs.selected[hunk_index] == true
end

--- Get all selected hunk indices for a file
---@param filepath string
---@return integer[]
function M.get_selected(filepath)
  local fs = hunk_state[filepath]
  if not fs then return {} end

  local result = {}
  for idx, _ in pairs(fs.selected) do
    table.insert(result, idx)
  end
  table.sort(result)
  return result
end

--- Clear selection for a file
---@param filepath string
function M.clear(filepath)
  if hunk_state[filepath] then
    hunk_state[filepath].selected = {}
  end
end

--- Clear all hunk state
function M.clear_all()
  hunk_state = {}
end

--- Stage the hunk under the cursor in the current diff buffer
---@param filepath string
---@param section string
function M.stage_current_hunk(filepath, section)
  local fs = hunk_state[filepath]

  if not fs or #fs.hunks == 0 then
    -- Try to load hunks first
    M.load_hunks(filepath, section, function(hunks, header)
      if #hunks == 0 then
        vim.notify("No hunks found", vim.log.levels.INFO)
        return
      end
      M._do_stage_at_cursor(filepath, hunks, header)
    end)
    return
  end

  M._do_stage_at_cursor(filepath, fs.hunks, fs.header)
end

--- Internal: stage the hunk at cursor position
function M._do_stage_at_cursor(filepath, hunks, header)
  local git_root = state.get().git_root
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]

  local hunk_idx = parser.find_hunk_at_line(hunks, line_nr)
  if not hunk_idx then
    vim.notify("Cursor is not on a hunk", vim.log.levels.INFO)
    return
  end

  local hunk = hunks[hunk_idx]
  local patch_content = patch.make_patch(filepath, hunk, header)

  local ok, git_stage = pcall(require, "commit-view.git.stage")
  if ok and git_stage.stage_hunk then
    git_stage.stage_hunk(git_root, patch_content, function(success)
      if success then
        vim.notify("Hunk staged")
        -- Refresh diff view
        local diff_panel = require("commit-view.ui.diff_panel")
        diff_panel.show_diff(filepath, "unstaged")
      else
        vim.notify("Failed to stage hunk", vim.log.levels.ERROR)
      end
    end)
  end
end

--- Rollback the hunk under the cursor
---@param filepath string
---@param section string
function M.rollback_current_hunk(filepath, section)
  local fs = hunk_state[filepath]

  if not fs or #fs.hunks == 0 then
    M.load_hunks(filepath, section, function(hunks, header)
      if #hunks == 0 then
        vim.notify("No hunks found", vim.log.levels.INFO)
        return
      end
      M._do_rollback_at_cursor(filepath, hunks, header)
    end)
    return
  end

  M._do_rollback_at_cursor(filepath, fs.hunks, fs.header)
end

--- Internal: rollback hunk at cursor
function M._do_rollback_at_cursor(filepath, hunks, header)
  local git_root = state.get().git_root
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]

  local hunk_idx = parser.find_hunk_at_line(hunks, line_nr)
  if not hunk_idx then
    vim.notify("Cursor is not on a hunk", vim.log.levels.INFO)
    return
  end

  vim.ui.select({ "Yes", "No" }, {
    prompt = "Rollback this hunk?",
  }, function(choice)
    if choice ~= "Yes" then return end

    local hunk = hunks[hunk_idx]
    local patch_content = patch.make_patch(filepath, hunk, header)

    local ok, git_rollback = pcall(require, "commit-view.git.rollback")
    if ok and git_rollback.rollback_hunk then
      git_rollback.rollback_hunk(git_root, patch_content, function(success)
        if success then
          vim.notify("Hunk rolled back")
          -- Refresh
          local diff_panel = require("commit-view.ui.diff_panel")
          diff_panel.show_diff(filepath, "unstaged")
          local file_panel = require("commit-view.ui.file_panel")
          file_panel.refresh()
        else
          vim.notify("Failed to rollback hunk", vim.log.levels.ERROR)
        end
      end)
    end
  end)
end

return M
