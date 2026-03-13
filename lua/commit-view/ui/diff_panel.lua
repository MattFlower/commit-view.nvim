local state = require("commit-view.state")
local config = require("commit-view.config")
local git_diff = require("commit-view.git.diff")

local M = {}

--- Load file content into a diff buffer
---@param buf integer buffer number
---@param lines string[] content lines
---@param filetype string|nil optional filetype for syntax highlighting
local function set_buf_content(buf, lines, filetype)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  if filetype then
    vim.bo[buf].filetype = filetype
  end
end

--- Detect filetype from filepath
---@param filepath string
---@return string
local function detect_filetype(filepath)
  local ft = vim.filetype.match({ filename = filepath })
  return ft or ""
end

--- Enable diff mode on a window
---@param win integer window id
local function enable_diff(win)
  vim.api.nvim_win_call(win, function()
    vim.cmd("diffthis")
  end)
end

--- Disable diff mode on a window
---@param win integer window id
local function disable_diff(win)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_call(win, function()
      vim.cmd("diffoff")
    end)
  end
end

--- Show the side-by-side diff for a file
---@param filepath string relative path from git root
---@param section string "staged"|"unstaged"|"untracked"
function M.show_diff(filepath, section)
  local s = state.get()
  local git_root = s.git_root

  local old_buf = s.bufs.diff_old
  local new_buf = s.bufs.diff_new
  local old_win = s.wins.diff_old
  local new_win = s.wins.diff_new

  if not (old_buf and new_buf and old_win and new_win) then
    vim.notify("CommitView: diff panels not available", vim.log.levels.ERROR)
    return
  end

  if not (vim.api.nvim_win_is_valid(old_win) and vim.api.nvim_win_is_valid(new_win)) then
    vim.notify("CommitView: diff windows are invalid", vim.log.levels.ERROR)
    return
  end

  -- Disable existing diff mode
  disable_diff(old_win)
  disable_diff(new_win)

  local ft = detect_filetype(filepath)

  if section == "untracked" then
    -- Untracked file: old is empty, new is the file content
    set_buf_content(old_buf, { "" }, ft)
    local new_lines = git_diff.read_working_file(git_root, filepath)
    set_buf_content(new_buf, new_lines or { "(cannot read file)" }, ft)
  elseif section == "staged" then
    -- Staged changes: old = HEAD version, new = index version
    local old_lines = git_diff.show_head_sync(git_root, filepath)
    set_buf_content(old_buf, old_lines or { "(new file)" }, ft)

    -- Get index version
    local index_lines = vim.fn.systemlist({ "git", "-C", git_root, "show", ":" .. filepath })
    if vim.v.shell_error ~= 0 then
      index_lines = { "(cannot read staged version)" }
    end
    set_buf_content(new_buf, index_lines, ft)
  else
    -- Unstaged changes: old = HEAD version (or index), new = working tree
    local old_lines = git_diff.show_head_sync(git_root, filepath)
    set_buf_content(old_buf, old_lines or { "(new file)" }, ft)

    local new_lines = git_diff.read_working_file(git_root, filepath)
    set_buf_content(new_buf, new_lines or { "(cannot read file)" }, ft)
  end

  -- Store filepath in buffer variables for identification (no nvim_buf_set_name
  -- to avoid ghost files on disk when Neovim exits)
  vim.b[old_buf].commit_view_diff_file = filepath
  vim.b[new_buf].commit_view_diff_file = filepath

  -- Enable diff mode on both windows
  enable_diff(old_win)
  enable_diff(new_win)

  -- Set window options for diff viewing
  for _, win in ipairs({ old_win, new_win }) do
    vim.wo[win].scrollbind = true
    vim.wo[win].cursorbind = true
    vim.wo[win].foldmethod = "diff"
    vim.wo[win].foldlevel = 99  -- show all folds open
  end

  -- Sync scroll when mouse wheel scrolls the unfocused diff pane.
  -- scrollbind only syncs FROM the focused window, so mouse-wheeling the
  -- non-focused pane causes it to snap back. Fix: update the focused pane
  -- to match, then reset the scrollbind baseline with :syncbind.
  local group = vim.api.nvim_create_augroup("CommitViewScrollSync", { clear = true })
  local syncing = false
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function()
      if syncing then return end
      local focused = vim.api.nvim_get_current_win()

      -- Check if an unfocused diff window was scrolled
      for win_id_str, _ in pairs(vim.v.event) do
        if win_id_str ~= "all" then
          local win_id = tonumber(win_id_str)
          if (win_id == old_win or win_id == new_win) and win_id ~= focused then
            -- Unfocused diff pane was scrolled (mouse wheel)
            local other = (win_id == old_win) and new_win or old_win
            if vim.api.nvim_win_is_valid(win_id) and vim.api.nvim_win_is_valid(other) then
              syncing = true
              local topline = vim.fn.getwininfo(win_id)[1].topline
              vim.api.nvim_win_call(other, function()
                vim.fn.winrestview({ topline = topline })
              end)
              vim.cmd("syncbind")
              vim.schedule(function() syncing = false end)
            end
            return
          end
        end
      end
    end,
  })

  -- Set up diff-panel specific keymaps
  M.setup_diff_keymaps(old_buf, new_buf, filepath, section)

  -- Jump to first difference
  vim.api.nvim_set_current_win(new_win)
  pcall(vim.cmd, "normal! gg]c")

  -- Return focus to file panel
  if s.wins.file_panel and vim.api.nvim_win_is_valid(s.wins.file_panel) then
    vim.api.nvim_set_current_win(s.wins.file_panel)
  end
end

--- Clear the diff panels
function M.clear()
  local s = state.get()

  for _, name in ipairs({ "diff_old", "diff_new" }) do
    local win = s.wins[name]
    local buf = s.bufs[name]

    if win and vim.api.nvim_win_is_valid(win) then
      disable_diff(win)
    end

    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "",
        "  Select a file and press <Enter> to view diff",
      })
      vim.bo[buf].modifiable = false
    end
  end
end

--- Set up keymaps specific to the diff panel buffers
---@param old_buf integer
---@param new_buf integer
---@param filepath string
---@param section string
function M.setup_diff_keymaps(old_buf, new_buf, filepath, section)
  local cfg = config.get()
  local s = state.get()

  for _, buf in ipairs({ old_buf, new_buf }) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      -- Go to source file from diff
      vim.keymap.set("n", cfg.keymaps.goto_source or cfg.keymaps.goto_file, function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local full_path = s.git_root .. "/" .. filepath
        require("commit-view").close()
        vim.cmd("edit " .. vim.fn.fnameescape(full_path))
        -- Try to position at the right line (approximate from new buffer)
        pcall(vim.api.nvim_win_set_cursor, 0, { cursor[1], 0 })
      end, { buffer = buf, noremap = true, silent = true, desc = "Go to source" })

      -- Stage hunk (placeholder for Phase 4)
      vim.keymap.set("n", cfg.keymaps.stage_hunk, function()
        local ok, hunk_ops = pcall(require, "commit-view.hunk.selector")
        if ok and hunk_ops.stage_current_hunk then
          hunk_ops.stage_current_hunk(filepath, section)
        else
          vim.notify("Hunk staging not yet available", vim.log.levels.INFO)
        end
      end, { buffer = buf, noremap = true, silent = true, desc = "Stage hunk" })

      -- Rollback hunk (placeholder for Phase 4)
      vim.keymap.set("n", cfg.keymaps.rollback_hunk, function()
        local ok, hunk_ops = pcall(require, "commit-view.hunk.selector")
        if ok and hunk_ops.rollback_current_hunk then
          hunk_ops.rollback_current_hunk(filepath, section)
        else
          vim.notify("Hunk rollback not yet available", vim.log.levels.INFO)
        end
      end, { buffer = buf, noremap = true, silent = true, desc = "Rollback hunk" })
    end
  end
end

return M
