local M = {}

-- Detect Nerd Font availability via nvim-web-devicons
local has_nerd_font = pcall(require, "nvim-web-devicons")

M.defaults = {
  -- Width of the file panel as a fraction of the editor width
  file_panel_width = 0.25,
  -- Height of the commit panel in lines
  commit_panel_height = 8,
  -- Icons (Nerd Font auto-detected via nvim-web-devicons, ASCII fallback)
  icons = {
    -- U+F046 nf-fa-check_square_o / U+F096 nf-fa-square_o
    checked = has_nerd_font and vim.fn.nr2char(0xf046) or "[x]",
    unchecked = has_nerd_font and vim.fn.nr2char(0xf096) or "[ ]",
    modified = "M",
    added = "A",
    deleted = "D",
    renamed = "R",
    copied = "C",
    untracked = "?",
    section_open = "",
    section_closed = "",
  },
  -- Keymaps (set to false to disable)
  keymaps = {
    close = "q",
    commit = "<C-c>r",
    commit_and_push = "<C-c>p",
    cycle_panel = "<Tab>",
    cycle_panel_back = "<S-Tab>",
    help = "?",
    -- File panel
    toggle_select = "<Space>",
    toggle_select_alt = "x",
    open_diff = "<CR>",
    open_diff_alt = "l",
    select_all = "a",
    deselect_all = "u",
    rollback_file = "R",
    goto_file = "gf",
    toggle_section = "o",
    -- Diff panel
    stage_hunk = "s",
    unstage_hunk = "u",
    rollback_hunk = "R",
    toggle_hunk = "<Space>",
    goto_source = "gf",
    -- Commit panel
    toggle_amend = "<C-a>",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts)
  M.setup_highlights()
end

function M.setup_highlights()
  local hl = vim.api.nvim_set_hl
  hl(0, "CommitViewChecked", { link = "DiagnosticOk", default = true })
  hl(0, "CommitViewUnchecked", { link = "Comment", default = true })
  hl(0, "CommitViewModified", { link = "DiagnosticWarn", default = true })
  hl(0, "CommitViewAdded", { link = "DiagnosticOk", default = true })
  hl(0, "CommitViewDeleted", { link = "DiagnosticError", default = true })
  hl(0, "CommitViewRenamed", { link = "DiagnosticInfo", default = true })
  hl(0, "CommitViewUntracked", { link = "Comment", default = true })
  hl(0, "CommitViewSectionHeader", { link = "Title", default = true })
  hl(0, "CommitViewAmendOn", { link = "DiagnosticWarn", default = true })
  hl(0, "CommitViewActionBar", { link = "Comment", default = true })
  hl(0, "CommitViewHunkHeader", { link = "Function", default = true })
end

function M.get()
  if vim.tbl_isempty(M.options) then
    M.setup({})
  end
  return M.options
end

return M
