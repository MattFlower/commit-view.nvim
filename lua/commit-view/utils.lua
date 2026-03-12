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

--- Create a scratch buffer with standard options
---@param name string buffer name for identification
---@return integer bufnr
function M.create_scratch_buf(name)
  local full_name = "commit-view://" .. name

  -- Wipe any existing buffer with this name to avoid E95
  local existing = vim.fn.bufnr(full_name)
  if existing ~= -1 then
    pcall(vim.api.nvim_buf_delete, existing, { force = true })
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, full_name)
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
