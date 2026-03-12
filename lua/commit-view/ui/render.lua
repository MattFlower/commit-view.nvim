local NuiLine = require("nui.line")
local NuiText = require("nui.text")
local config = require("commit-view.config")

local M = {}

--- Get the appropriate highlight group for a git status code
---@param status string single character status code
---@return string highlight group name
function M.status_hl(status)
  local map = {
    M = "CommitViewModified",
    A = "CommitViewAdded",
    D = "CommitViewDeleted",
    R = "CommitViewRenamed",
    C = "CommitViewRenamed",
    ["?"] = "CommitViewUntracked",
  }
  return map[status] or "Normal"
end

--- Get the display icon for a git status code
---@param status string single character status code
---@return string
function M.status_icon(status)
  local cfg = config.get()
  local map = {
    M = cfg.icons.modified,
    A = cfg.icons.added,
    D = cfg.icons.deleted,
    R = cfg.icons.renamed,
    C = cfg.icons.copied,
    ["?"] = cfg.icons.untracked,
  }
  return map[status] or status
end

--- Get file icon from nvim-web-devicons if available
---@param filepath string
---@return string icon, string highlight
function M.file_icon(filepath)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok then
    local ext = filepath:match("%.(%w+)$")
    local icon, hl = devicons.get_icon(filepath, ext, { default = true })
    return icon or "", hl or "Normal"
  end
  return "", "Normal"
end

--- Create a checkbox NuiText
---@param checked boolean
---@return NuiText
function M.checkbox(checked)
  local cfg = config.get()
  if checked then
    return NuiText(" " .. cfg.icons.checked .. " ", "CommitViewChecked")
  else
    return NuiText(" " .. cfg.icons.unchecked .. " ", "CommitViewUnchecked")
  end
end

--- Create a section header NuiLine
---@param text string section name
---@param expanded boolean
---@param count integer number of items
---@return NuiLine
function M.section_header(text, expanded, count)
  local cfg = config.get()
  local line = NuiLine()
  local arrow = expanded and cfg.icons.section_open or cfg.icons.section_closed
  line:append(arrow .. " ", "CommitViewSectionHeader")
  line:append(text, "CommitViewSectionHeader")
  line:append(" (" .. count .. ")", "Comment")
  return line
end

--- Create a file entry NuiLine
---@param filepath string
---@param status string git status code
---@param checked boolean
---@return NuiLine
function M.file_entry(filepath, status, checked)
  local line = NuiLine()
  line:append(M.checkbox(checked))
  line:append(M.status_icon(status) .. " ", M.status_hl(status))
  local icon, icon_hl = M.file_icon(filepath)
  if icon ~= "" then
    line:append(icon .. " ", icon_hl)
  end
  line:append(filepath)
  return line
end

return M
