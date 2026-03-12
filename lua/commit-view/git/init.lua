local M = {}

M.status = require("commit-view.git.status")
M.diff = require("commit-view.git.diff")
M.stage = require("commit-view.git.stage")
M.commit = require("commit-view.git.commit")
M.rollback = require("commit-view.git.rollback")

return M
