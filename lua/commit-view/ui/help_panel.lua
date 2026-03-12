local config = require("commit-view.config")

local M = {}

local help_win = nil
local help_buf = nil

--- Build the help text from config keymaps
---@return string[]
local function build_help_lines()
  local cfg = config.get()
  local km = cfg.keymaps

  return {
    " CommitView Keybindings",
    " ═══════════════════════════════════",
    "",
    " Global",
    " ──────────────────────────────────",
    string.format("  %-14s  Close commit view", km.close),
    string.format("  %-14s  Commit selected files", km.commit),
    string.format("  %-14s  Commit and push", km.commit_and_push),
    string.format("  %-14s  Next panel", km.cycle_panel),
    string.format("  %-14s  Previous panel", km.cycle_panel_back),
    string.format("  %-14s  Toggle this help", km.help),
    "",
    " File Panel",
    " ──────────────────────────────────",
    string.format("  %-14s  Toggle file selection", km.toggle_select),
    string.format("  %-14s  Open diff", km.open_diff),
    string.format("  %-14s  Select all files", km.select_all),
    string.format("  %-14s  Deselect all files", km.deselect_all),
    string.format("  %-14s  Rollback file", km.rollback_file),
    string.format("  %-14s  Go to source file", km.goto_file),
    string.format("  %-14s  Expand/collapse section", km.toggle_section),
    "",
    " Diff Panel",
    " ──────────────────────────────────",
    "  ]c              Next hunk",
    "  [c              Previous hunk",
    string.format("  %-14s  Stage hunk", km.stage_hunk),
    string.format("  %-14s  Rollback hunk", km.rollback_hunk),
    string.format("  %-14s  Go to source line", km.goto_source),
    "",
    " Commit Panel",
    " ──────────────────────────────────",
    string.format("  %-14s  Toggle amend mode", km.toggle_amend),
    string.format("  %-14s  Commit", km.commit),
    string.format("  %-14s  Commit and push", km.commit_and_push),
    "",
    " Press ? or q to close this help",
  }
end

--- Toggle the help popup
function M.toggle()
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    M.close()
    return
  end

  M.open()
end

--- Open the help popup
function M.open()
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    return
  end

  local lines = build_help_lines()

  -- Calculate dimensions
  local width = 42
  local height = #lines

  -- Center in the editor
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)

  -- Create buffer
  help_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, lines)
  vim.bo[help_buf].modifiable = false
  vim.bo[help_buf].bufhidden = "wipe"

  -- Create floating window
  help_win = vim.api.nvim_open_win(help_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Help ",
    title_pos = "center",
  })

  vim.wo[help_win].cursorline = false
  vim.wo[help_win].wrap = false

  -- Close on q or ?
  local close_opts = { buffer = help_buf, noremap = true, silent = true }
  vim.keymap.set("n", "q", function() M.close() end, close_opts)
  vim.keymap.set("n", "?", function() M.close() end, close_opts)
  vim.keymap.set("n", "<Esc>", function() M.close() end, close_opts)

  -- Close when leaving the buffer
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = help_buf,
    once = true,
    callback = function()
      M.close()
    end,
  })
end

--- Close the help popup
function M.close()
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    vim.api.nvim_win_close(help_win, true)
  end
  help_win = nil
  help_buf = nil
end

return M
