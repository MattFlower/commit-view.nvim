local state = require("commit-view.state")
local config = require("commit-view.config")
local git_status = require("commit-view.git.status")
local utils = require("commit-view.utils")

local M = {}

--- Create the tab page and window layout
local function create_layout()
  local cfg = config.get()

  -- Remember current tab, open new tab
  vim.cmd("tabnew")
  state.set_tab(vim.fn.tabpagenr())

  -- Create the commit panel buffer first (bottom)
  local commit_buf = utils.create_scratch_buf("commit-message")
  vim.bo[commit_buf].buftype = ""  -- editable
  vim.bo[commit_buf].filetype = "gitcommit"
  state.set_buf("commit_panel", commit_buf)

  -- Create file panel buffer
  local file_buf = utils.create_scratch_buf("file-panel")
  state.set_buf("file_panel", file_buf)

  -- Create diff buffers
  local diff_old_buf = utils.create_scratch_buf("diff-old")
  local diff_new_buf = utils.create_scratch_buf("diff-new")
  state.set_buf("diff_old", diff_old_buf)
  state.set_buf("diff_new", diff_new_buf)

  -- Build the window layout:
  -- Start with the current window which will become the diff-new (top-right)
  -- 1. Create bottom split for commit message
  local commit_height = cfg.commit_panel_height

  -- Set up the main window with diff-new buffer first
  vim.api.nvim_win_set_buf(0, diff_new_buf)
  local main_win = vim.api.nvim_get_current_win()

  -- Create bottom horizontal split for commit panel
  vim.cmd("botright " .. commit_height .. "split")
  local commit_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(commit_win, commit_buf)
  state.set_win("commit_panel", commit_win)

  -- Go back to main window
  vim.api.nvim_set_current_win(main_win)

  -- Create left vertical split for file panel
  local file_width = math.floor(vim.o.columns * cfg.file_panel_width)
  vim.cmd("topleft " .. file_width .. "vnew")
  local file_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(file_win, file_buf)
  state.set_win("file_panel", file_win)

  -- main_win still has diff_new_buf. Split it for diff_old on the left side.
  vim.api.nvim_set_current_win(main_win)
  vim.cmd("leftabove vsplit")
  local diff_old_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(diff_old_win, diff_old_buf)
  state.set_win("diff_old", diff_old_win)
  state.set_win("diff_new", main_win)

  -- Set window options
  M.configure_file_panel_win(file_win)
  M.configure_diff_win(diff_old_win)
  M.configure_diff_win(main_win)
  M.configure_commit_panel_win(commit_win)

  -- Set placeholder content for diff panels
  utils.with_modifiable(diff_old_buf, function()
    vim.api.nvim_buf_set_lines(diff_old_buf, 0, -1, false, {
      "",
      "  Select a file and press <Enter> to view diff",
    })
  end)
  utils.with_modifiable(diff_new_buf, function()
    vim.api.nvim_buf_set_lines(diff_new_buf, 0, -1, false, {
      "",
      "  Select a file and press <Enter> to view diff",
    })
  end)

  -- Focus the file panel
  vim.api.nvim_set_current_win(file_win)
end

function M.configure_file_panel_win(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].wrap = false
  vim.wo[win].spell = false
  vim.wo[win].cursorline = true
  vim.wo[win].winfixwidth = true
end

function M.configure_diff_win(win)
  vim.wo[win].number = true
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "yes"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].wrap = false
  vim.wo[win].spell = false
  vim.wo[win].cursorline = true
end

function M.configure_commit_panel_win(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].wrap = true
  vim.wo[win].spell = true
  vim.wo[win].winfixheight = true
end

--- Set up keymaps that work in all panels
local function setup_global_keymaps()
  local s = state.get()
  local bufs = { s.bufs.file_panel, s.bufs.diff_old, s.bufs.diff_new, s.bufs.commit_panel }
  local cfg = config.get()

  for _, buf in ipairs(bufs) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      -- Close
      vim.keymap.set("n", cfg.keymaps.close, function()
        require("commit-view").close()
      end, { buffer = buf, noremap = true, silent = true, desc = "Close commit view" })

      -- Cycle panels
      vim.keymap.set("n", cfg.keymaps.cycle_panel, function()
        M.cycle_focus(1)
      end, { buffer = buf, noremap = true, silent = true, desc = "Next panel" })

      vim.keymap.set("n", cfg.keymaps.cycle_panel_back, function()
        M.cycle_focus(-1)
      end, { buffer = buf, noremap = true, silent = true, desc = "Previous panel" })

      -- Help
      if cfg.keymaps.help then
        vim.keymap.set("n", cfg.keymaps.help, function()
          require("commit-view.ui.help_panel").toggle()
        end, { buffer = buf, noremap = true, silent = true, desc = "Toggle help" })
      end
    end
  end
end

--- Cycle focus between panels
---@param direction integer 1 for forward, -1 for backward
function M.cycle_focus(direction)
  local s = state.get()
  local panel_order = { "file_panel", "diff_old", "diff_new", "commit_panel" }
  local current_win = vim.api.nvim_get_current_win()

  local current_idx = nil
  for i, name in ipairs(panel_order) do
    if s.wins[name] == current_win then
      current_idx = i
      break
    end
  end

  if not current_idx then
    -- Not in a known panel, go to file panel
    if s.wins.file_panel and vim.api.nvim_win_is_valid(s.wins.file_panel) then
      vim.api.nvim_set_current_win(s.wins.file_panel)
    end
    return
  end

  local next_idx = current_idx + direction
  if next_idx > #panel_order then
    next_idx = 1
  elseif next_idx < 1 then
    next_idx = #panel_order
  end

  local next_win = s.wins[panel_order[next_idx]]
  if next_win and vim.api.nvim_win_is_valid(next_win) then
    vim.api.nvim_set_current_win(next_win)
  end
end

--- Mount the commit view
function M.mount()
  create_layout()

  -- Load git status and populate file panel
  local s = state.get()
  local files, err = git_status.get_status_sync(s.git_root)
  if err then
    vim.notify("CommitView: " .. err, vim.log.levels.ERROR)
    return
  end

  state.set_files(files)

  -- Initialize file panel
  local ok, file_panel = pcall(require, "commit-view.ui.file_panel")
  if ok and file_panel.init then
    file_panel.init()
  end

  -- Initialize commit panel
  local cp_ok, commit_panel = pcall(require, "commit-view.ui.commit_panel")
  if cp_ok and commit_panel.init then
    commit_panel.init()
  end

  -- Set up global keymaps
  setup_global_keymaps()

  -- Set up commit/push keymaps on non-commit panels
  local km_ok, keymaps = pcall(require, "commit-view.ui.keymaps")
  if km_ok and keymaps.setup_commit_keymaps then
    keymaps.setup_commit_keymaps()
  end

  -- Set up autocmd to handle tab close
  vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      if state.is_open() and not vim.api.nvim_win_is_valid(s.wins.file_panel or -1) then
        state.reset()
      end
    end,
    once = true,
  })
end

--- Unmount the commit view
function M.unmount()
  local s = state.get()

  -- Close the tab
  if s.tab_nr then
    -- Switch to the tab first, then close it
    local target_tab = nil

    -- Find the tab (tab numbers can shift)
    for t = 1, vim.fn.tabpagenr("$") do
      vim.cmd(t .. "tabnext")
      local win = vim.fn.tabpagewinnr(t)
      local buf = vim.fn.winbufnr(win)
      local name = vim.api.nvim_buf_get_name(buf)
      if name:find("commit%-view://") then
        target_tab = t
        break
      end
    end

    if target_tab then
      vim.cmd(target_tab .. "tabnext")
      vim.cmd("tabclose")
    end

    -- Return to previous tab if possible
    if s.prev_tab_nr then
      local max_tab = vim.fn.tabpagenr("$")
      local goto_tab = math.min(s.prev_tab_nr, max_tab)
      vim.cmd(goto_tab .. "tabnext")
    end
  end
end

return M
