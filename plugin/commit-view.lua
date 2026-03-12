if vim.g.commit_view_loaded then
  return
end
vim.g.commit_view_loaded = 1

vim.api.nvim_create_user_command("CommitView", function()
  require("commit-view").open()
end, { nargs = 0, desc = "Open the commit view" })

vim.api.nvim_create_user_command("CommitViewClose", function()
  require("commit-view").close()
end, { nargs = 0, desc = "Close the commit view" })
