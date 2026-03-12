local M = {}

function M.setup(opts)
  require("commit-view.config").setup(opts or {})
end

function M.open()
  local state = require("commit-view.state")

  -- If state thinks it's open but the tab/windows are gone, force a cleanup
  if state.is_open() then
    local s = state.get()
    local still_alive = s.wins.file_panel
      and vim.api.nvim_win_is_valid(s.wins.file_panel)
    if still_alive then
      -- Actually still open — switch to it
      vim.api.nvim_set_current_win(s.wins.file_panel)
      return
    else
      -- Stale state — force reset
      M.force_reset()
    end
  end

  local git_root = state.detect_git_root()
  if not git_root then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  state.init(git_root)
  require("commit-view.ui").mount()
end

function M.close()
  local state = require("commit-view.state")
  if not state.is_open() then
    return
  end
  require("commit-view.ui").unmount()
  M.force_reset()
end

--- Reset all module-level state so CommitView can be reopened cleanly
function M.force_reset()
  local state = require("commit-view.state")
  -- Reset sub-module state
  local cp_ok, commit_panel = pcall(require, "commit-view.ui.commit_panel")
  if cp_ok and commit_panel.reset then
    commit_panel.reset()
  end
  local hs_ok, hunk_selector = pcall(require, "commit-view.hunk.selector")
  if hs_ok and hunk_selector.clear_all then
    hunk_selector.clear_all()
  end
  -- Reset file panel tree
  local fp_ok, file_panel = pcall(require, "commit-view.ui.file_panel")
  if fp_ok and file_panel.reset then
    file_panel.reset()
  end
  -- Clear scroll sync autocmds
  pcall(vim.api.nvim_del_augroup_by_name, "CommitViewScrollSync")
  state.reset()
end

return M
