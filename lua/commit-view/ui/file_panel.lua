local NuiTree = require("nui.tree")
local state = require("commit-view.state")
local config = require("commit-view.config")
local render = require("commit-view.ui.render")

local M = {}

local tree = nil

--- Build tree nodes from current state
---@return NuiTree.Node[]
local function build_nodes()
  local s = state.get()
  local files = s.files

  -- Group files by section
  local sections = {
    { key = "staged", label = "Changes", files = {} },
    { key = "unstaged", label = "Modified", files = {} },
    { key = "untracked", label = "Unversioned Files", files = {} },
  }

  local section_map = {}
  for _, sec in ipairs(sections) do
    section_map[sec.key] = sec
  end

  for _, file in ipairs(files) do
    local sec = section_map[file.section]
    if sec then
      table.insert(sec.files, file)
    end
  end

  -- Build tree nodes
  local root_nodes = {}
  for _, sec in ipairs(sections) do
    if #sec.files > 0 then
      local children = {}
      for _, file in ipairs(sec.files) do
        table.insert(children, NuiTree.Node({
          id = sec.key .. ":" .. file.filepath,
          filepath = file.filepath,
          status = file.status,
          status_type = file.status_type,
          section = sec.key,
          is_file = true,
        }))
      end

      table.insert(root_nodes, NuiTree.Node({
        id = "section:" .. sec.key,
        text = sec.label,
        section_key = sec.key,
        is_section = true,
        file_count = #sec.files,
      }, children))
    end
  end

  return root_nodes
end

--- Rebuild tree nodes in-place to force prepare_node re-evaluation.
--- NuiTree may cache prepare_node output; set_nodes + render guarantees fresh rendering.
local function rerender_tree()
  if not tree then return end

  -- Save cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)

  local nodes = build_nodes()
  tree:set_nodes(nodes)
  -- Expand all sections
  for _, node in ipairs(nodes) do
    node:expand()
  end
  tree:render()

  -- Restore cursor position (clamp to valid range)
  local s = state.get()
  local buf = s.bufs.file_panel
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local line_count = vim.api.nvim_buf_line_count(buf)
    local row = math.min(cursor[1], line_count)
    pcall(vim.api.nvim_win_set_cursor, 0, { row, cursor[2] })
  end
end

--- Render a single tree node
---@param node NuiTree.Node
---@return NuiLine
local function prepare_node(node)
  if node.is_section then
    return render.section_header(
      node.text,
      node:is_expanded(),
      node.file_count
    )
  end

  -- File node
  local checked = state.is_selected(node.filepath)
  return render.file_entry(node.filepath, node.status, checked)
end

--- Set up keymaps for the file panel buffer
local function setup_keymaps()
  local s = state.get()
  local buf = s.bufs.file_panel
  local cfg = config.get()

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Toggle file selection
  local function toggle_selection()
    if not tree then return end

    local node = tree:get_node()
    if not node then return end

    if node.is_section then
      local children = node:get_child_ids()
      for _, child_id in ipairs(children) do
        local child = tree:get_node(child_id)
        if child and child.is_file then
          state.toggle_selection(child.filepath)
        end
      end
    elseif node.is_file then
      state.toggle_selection(node.filepath)
    end

    rerender_tree()
  end

  vim.keymap.set("n", cfg.keymaps.toggle_select, toggle_selection,
    { buffer = buf, noremap = true, desc = "Toggle selection" })
  if cfg.keymaps.toggle_select_alt then
    vim.keymap.set("n", cfg.keymaps.toggle_select_alt, toggle_selection,
      { buffer = buf, noremap = true, desc = "Toggle selection" })
  end

  -- Expand/collapse section
  vim.keymap.set("n", cfg.keymaps.toggle_section, function()
    local node = tree:get_node()
    if not node then return end

    if node.is_section then
      if node:is_expanded() then
        node:collapse()
      else
        node:expand()
      end
      tree:render()
    end
  end, { buffer = buf, noremap = true, silent = true, desc = "Toggle section" })

  -- Select all
  vim.keymap.set("n", cfg.keymaps.select_all, function()
    state.select_all()
    rerender_tree()
  end, { buffer = buf, noremap = true, silent = true, desc = "Select all" })

  -- Deselect all
  vim.keymap.set("n", cfg.keymaps.deselect_all, function()
    state.deselect_all()
    rerender_tree()
  end, { buffer = buf, noremap = true, silent = true, desc = "Deselect all" })

  -- Open diff (Enter or l)
  local function open_diff()
    local node = tree:get_node()
    if not node or not node.is_file then return end

    state.set_current_file(node.filepath)

    local ok, diff_panel = pcall(require, "commit-view.ui.diff_panel")
    if ok and diff_panel.show_diff then
      diff_panel.show_diff(node.filepath, node.section)
    end
  end

  vim.keymap.set("n", cfg.keymaps.open_diff, open_diff,
    { buffer = buf, noremap = true, silent = true, desc = "Open diff" })
  vim.keymap.set("n", cfg.keymaps.open_diff_alt, open_diff,
    { buffer = buf, noremap = true, silent = true, desc = "Open diff" })

  -- Rollback file
  vim.keymap.set("n", cfg.keymaps.rollback_file, function()
    local node = tree:get_node()
    if not node or not node.is_file then return end

    vim.ui.select({ "Yes", "No" }, {
      prompt = "Rollback all changes in " .. node.filepath .. "?",
    }, function(choice)
      if choice == "Yes" then
        local ok, rollback = pcall(require, "commit-view.git.rollback")
        if ok and rollback.rollback_file then
          rollback.rollback_file(state.get().git_root, node.filepath, function(success)
            if success then
              vim.notify("Rolled back: " .. node.filepath)
              M.refresh()
            else
              vim.notify("Rollback failed: " .. node.filepath, vim.log.levels.ERROR)
            end
          end)
        end
      end
    end)
  end, { buffer = buf, noremap = true, silent = true, desc = "Rollback file" })

  -- Go to source file
  vim.keymap.set("n", cfg.keymaps.goto_file, function()
    local node = tree:get_node()
    if not node or not node.is_file then return end

    local filepath = state.get().git_root .. "/" .. node.filepath
    require("commit-view").close()
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  end, { buffer = buf, noremap = true, silent = true, desc = "Go to source file" })
end

--- Initialize the file panel
function M.init()
  local s = state.get()
  local buf = s.bufs.file_panel

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local nodes = build_nodes()

  tree = NuiTree({
    bufnr = buf,
    nodes = nodes,
    prepare_node = prepare_node,
  })

  -- Expand all sections by default
  for _, node in ipairs(nodes) do
    node:expand()
  end

  tree:render()
  setup_keymaps()
end

--- Refresh the file panel with fresh git status
function M.refresh()
  local s = state.get()
  local git_status = require("commit-view.git.status")

  local files, err = git_status.get_status_sync(s.git_root)
  if err then
    vim.notify("CommitView: " .. err, vim.log.levels.ERROR)
    return
  end

  state.set_files(files)
  rerender_tree()
end

--- Reset module state so CommitView can be reopened cleanly
function M.reset()
  tree = nil
end

--- Get the tree instance (for external use)
---@return NuiTree|nil
function M.get_tree()
  return tree
end

return M
