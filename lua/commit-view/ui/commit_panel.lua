local state = require("commit-view.state")
local config = require("commit-view.config")

local M = {}

-- Local state for commit panel
local amend_mode = false
local action_bar_ns = vim.api.nvim_create_namespace("commit_view_action_bar")

--- Initialize the commit panel with keymaps and action bar
function M.init()
  local s = state.get()
  local buf = s.bufs.commit_panel
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local cfg = config.get()

  -- Set up keymaps for the commit panel buffer
  local opts = { buffer = buf, noremap = true, silent = true }

  -- Toggle amend
  vim.keymap.set({ "n", "i" }, cfg.keymaps.toggle_amend, function()
    M.toggle_amend()
  end, vim.tbl_extend("force", opts, { desc = "Toggle amend mode" }))

  -- Commit (from commit panel)
  vim.keymap.set({ "n", "i" }, cfg.keymaps.commit, function()
    M.do_commit(false)
  end, vim.tbl_extend("force", opts, { desc = "Commit" }))

  -- Commit and push (from commit panel)
  vim.keymap.set({ "n", "i" }, cfg.keymaps.commit_and_push, function()
    M.do_commit(true)
  end, vim.tbl_extend("force", opts, { desc = "Commit and push" }))

  -- Make the buffer writable and set up for multi-line editing
  vim.bo[buf].modifiable = true
  vim.bo[buf].buftype = ""
  vim.bo[buf].filetype = "gitcommit"

  -- Pre-fill with empty lines so the commit area feels multi-line
  local height = cfg.commit_panel_height or 8
  local empty_lines = {}
  for _ = 1, height do
    table.insert(empty_lines, "")
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, empty_lines)

  -- Place cursor at line 1
  local win = s.wins.commit_panel
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end

  -- Render action bar
  M.render_action_bar()
end

--- Render the virtual text action bar at the bottom of the commit buffer
function M.render_action_bar()
  local s = state.get()
  local buf = s.bufs.commit_panel
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local cfg = config.get()

  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(buf, action_bar_ns, 0, -1)

  -- Build action bar text
  local amend_text = amend_mode and "[x] Amend" or "[ ] Amend"
  local bar = string.format(
    "  %s (%s)    [Commit] %s    [Commit & Push] %s",
    amend_text,
    cfg.keymaps.toggle_amend,
    cfg.keymaps.commit,
    cfg.keymaps.commit_and_push
  )

  -- Place as virtual text on the last line
  local line_count = vim.api.nvim_buf_line_count(buf)
  local last_line = math.max(0, line_count - 1)

  vim.api.nvim_buf_set_extmark(buf, action_bar_ns, last_line, 0, {
    virt_lines = {
      {
        { bar, amend_mode and "CommitViewAmendOn" or "CommitViewActionBar" },
      },
    },
    virt_lines_above = false,
  })
end

--- Toggle amend mode
function M.toggle_amend()
  amend_mode = not amend_mode

  if amend_mode then
    -- Load last commit message into the buffer
    local s = state.get()
    local git_commit = require("commit-view.git.commit")
    git_commit.get_last_message(s.git_root, function(msg)
      if msg then
        local buf = s.bufs.commit_panel
        if buf and vim.api.nvim_buf_is_valid(buf) then
          local lines = vim.split(msg, "\n")
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        end
      end
      M.render_action_bar()
    end)
  else
    M.render_action_bar()
  end

  vim.notify(amend_mode and "Amend mode ON" or "Amend mode OFF")
end

--- Get the commit message from the buffer
---@return string
function M.get_message()
  local s = state.get()
  local buf = s.bufs.commit_panel
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return ""
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Trim trailing empty lines
  while #lines > 0 and lines[#lines]:match("^%s*$") do
    table.remove(lines)
  end
  return table.concat(lines, "\n")
end

--- Check if amend mode is on
---@return boolean
function M.is_amend()
  return amend_mode
end

--- Perform the commit operation
---@param and_push boolean whether to also push after commit
function M.do_commit(and_push)
  local s = state.get()
  local message = M.get_message()

  if not amend_mode and (message == "" or message:match("^%s*$")) then
    vim.notify("Commit message is empty", vim.log.levels.WARN)
    return
  end

  -- Gather selected files
  local selected = state.get_selected_files()
  if #selected == 0 and not amend_mode then
    vim.notify("No files selected for commit", vim.log.levels.WARN)
    return
  end

  local filepaths = {}
  for _, file in ipairs(selected) do
    table.insert(filepaths, file.filepath)
  end

  local git_commit = require("commit-view.git.commit")
  git_commit.commit(s.git_root, filepaths, message, amend_mode, function(success, output)
    if not success then
      vim.notify("Commit failed: " .. output, vim.log.levels.ERROR)
      return
    end

    vim.notify("Committed successfully")

    if and_push then
      vim.notify("Pushing...")
      git_commit.push(s.git_root, function(push_ok, push_output)
        if push_ok then
          vim.notify("Pushed successfully")
        else
          vim.notify("Push failed: " .. push_output, vim.log.levels.ERROR)
        end
        -- Close commit view on success
        require("commit-view").close()
      end)
    else
      -- Close commit view on success
      require("commit-view").close()
    end
  end)
end

--- Reset the commit panel state
function M.reset()
  amend_mode = false
end

return M
