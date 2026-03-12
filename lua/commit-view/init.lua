local M = {}

function M.setup(opts)
  require("commit-view.config").setup(opts or {})
end

function M.open()
  local state = require("commit-view.state")
  if state.is_open() then
    vim.notify("CommitView is already open", vim.log.levels.WARN)
    return
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
  -- Reset sub-module state
  local cp_ok, commit_panel = pcall(require, "commit-view.ui.commit_panel")
  if cp_ok and commit_panel.reset then
    commit_panel.reset()
  end
  local hs_ok, hunk_selector = pcall(require, "commit-view.hunk.selector")
  if hs_ok and hunk_selector.clear_all then
    hunk_selector.clear_all()
  end
  state.reset()
end

return M
