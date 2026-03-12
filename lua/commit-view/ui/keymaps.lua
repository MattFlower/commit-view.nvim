local state = require("commit-view.state")
local config = require("commit-view.config")

local M = {}

--- Set up commit/push keymaps on all panel buffers (except commit_panel which has its own)
function M.setup_commit_keymaps()
  local s = state.get()
  local cfg = config.get()

  -- Buffers that need commit keymaps (file_panel and diff panels)
  -- commit_panel already has its own keymaps set up in commit_panel.init()
  local bufs = { s.bufs.file_panel, s.bufs.diff_old, s.bufs.diff_new }

  for _, buf in ipairs(bufs) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.keymap.set("n", cfg.keymaps.commit, function()
        local commit_panel = require("commit-view.ui.commit_panel")
        commit_panel.do_commit(false)
      end, { buffer = buf, noremap = true, silent = true, desc = "Commit selected files" })

      vim.keymap.set("n", cfg.keymaps.commit_and_push, function()
        local commit_panel = require("commit-view.ui.commit_panel")
        commit_panel.do_commit(true)
      end, { buffer = buf, noremap = true, silent = true, desc = "Commit and push" })
    end
  end
end

return M
