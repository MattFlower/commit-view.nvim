local M = {}

--- Join path components with /
---@param ... string
---@return string
function M.path_join(...)
  return table.concat({ ... }, "/")
end

--- Get the filename from a path
---@param path string
---@return string
function M.basename(path)
  return path:match("[^/]+$") or path
end

--- Get the directory from a path
---@param path string
---@return string
function M.dirname(path)
  return path:match("(.+)/[^/]+$") or ""
end

--- Create a scratch buffer with standard options.
--- Uses buffer-local variables for identification instead of buffer names
--- to avoid ghost files on disk when Neovim exits.
---@param name string logical name for identification (stored as b:commit_view_name)
---@return integer bufnr
function M.create_scratch_buf(name)
  -- Wipe any leftover buffer from a previous session
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.b[b].commit_view_name == name then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.b[buf].commit_view = true
  vim.b[buf].commit_view_name = name
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  return buf
end

--- Set common readonly buffer options
---@param buf integer
function M.set_buf_readonly(buf)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
end

--- Temporarily make buffer modifiable, run fn, then set readonly again
---@param buf integer
---@param fn function
function M.with_modifiable(buf, fn)
  vim.bo[buf].modifiable = true
  fn()
  vim.bo[buf].modifiable = false
end

return M
