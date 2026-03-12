local M = {}

-- Singleton state
local state = {
  open = false,
  git_root = nil,
  files = {},        -- parsed git status entries
  selections = {},   -- { [filepath] = true/false } for commit selection
  current_file = nil, -- filepath currently shown in diff panel
  tab_nr = nil,      -- tab number of the commit view
  prev_tab_nr = nil, -- tab number to return to on close
  -- Window IDs
  wins = {
    file_panel = nil,
    diff_old = nil,
    diff_new = nil,
    commit_panel = nil,
  },
  -- Buffer numbers
  bufs = {
    file_panel = nil,
    diff_old = nil,
    diff_new = nil,
    commit_panel = nil,
  },
}

function M.detect_git_root()
  local result = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result[1]
end

function M.init(git_root)
  state.git_root = git_root
  state.open = true
  state.files = {}
  state.selections = {}
  state.current_file = nil
  state.prev_tab_nr = vim.fn.tabpagenr()
end

function M.reset()
  state.open = false
  state.git_root = nil
  state.files = {}
  state.selections = {}
  state.current_file = nil
  state.tab_nr = nil
  state.prev_tab_nr = nil
  state.wins = { file_panel = nil, diff_old = nil, diff_new = nil, commit_panel = nil }
  state.bufs = { file_panel = nil, diff_old = nil, diff_new = nil, commit_panel = nil }
end

function M.is_open()
  return state.open
end

function M.get()
  return state
end

function M.set_files(files)
  state.files = files
  -- Default all files to deselected
  for _, file in ipairs(files) do
    if state.selections[file.filepath] == nil then
      state.selections[file.filepath] = false
    end
  end
end

function M.toggle_selection(filepath)
  state.selections[filepath] = not state.selections[filepath]
end

function M.select_all()
  for _, file in ipairs(state.files) do
    state.selections[file.filepath] = true
  end
end

function M.deselect_all()
  for _, file in ipairs(state.files) do
    state.selections[file.filepath] = false
  end
end

function M.is_selected(filepath)
  return state.selections[filepath] == true
end

function M.get_selected_files()
  local selected = {}
  for _, file in ipairs(state.files) do
    if state.selections[file.filepath] then
      table.insert(selected, file)
    end
  end
  return selected
end

function M.set_current_file(filepath)
  state.current_file = filepath
end

function M.set_tab(tab_nr)
  state.tab_nr = tab_nr
end

function M.set_win(name, win_id)
  state.wins[name] = win_id
end

function M.set_buf(name, buf_nr)
  state.bufs[name] = buf_nr
end

return M
