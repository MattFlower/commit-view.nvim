# commit-view.nvim

An IntelliJ-style commit UI for Neovim. Opens a dedicated tab with a file
selection panel, side-by-side diff viewer, and commit message editor — all
driven by keyboard shortcuts.

## Features

- **Selective file commit** — checkbox-style file selection (not git staging).
  Files are only `git add`-ed at commit time.
- **Side-by-side diff** — native Neovim diff mode with synchronized scrolling,
  triggered by pressing `<CR>` on a file.
- **Hunk-level operations** — stage or rollback individual hunks from the diff
  panel.
- **File rollback** — revert a file's changes back to HEAD.
- **Unversioned files** — shown in a separate section, auto-added on commit
  when selected.
- **Commit message editor** — `gitcommit` filetype buffer with amend toggle,
  "Commit" and "Commit and Push" actions.
- **Dedicated tab layout** — uses the full screen: file panel on the left,
  two diff panes top-right, commit message at the bottom.
- **Help popup** — press `?` from any panel.

## Requirements

- Neovim **0.9+**
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) — tree widget and text
  rendering
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) — async job runner
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)
  *(optional)* — file type icons in the file panel
- **git** on `$PATH`

## Installation

### lazy.nvim

```lua
{
  "MattFlower/commit-view.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- optional
  },
  cmd = { "CommitView", "CommitViewClose" },
  keys = {
    { "<leader>gc", "<cmd>CommitView<cr>", desc = "Open commit view" },
  },
  opts = {},
}
```

### packer.nvim

```lua
use {
  "MattFlower/commit-view.nvim",
  requires = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- optional
  },
  config = function()
    require("commit-view").setup()
  end,
}
```

### Manual / vim-plug

Clone the repo into your plugin directory and add the dependencies. Then call
`setup()` somewhere in your config:

```lua
require("commit-view").setup()
```

## Usage

```
:CommitView        " open the commit view in a new tab
:CommitViewClose   " close it and return to the previous tab
```

Or bind it to a key:

```lua
vim.keymap.set("n", "<leader>gc", "<cmd>CommitView<cr>")
```

## Default Keybindings

### Global (all panels)

| Key          | Action                |
|--------------|-----------------------|
| `q`          | Close commit view     |
| `<C-c>r`    | Commit                |
| `<C-c>p`    | Commit and push       |
| `<Tab>`      | Next panel            |
| `<S-Tab>`    | Previous panel        |
| `?`          | Toggle help popup     |

### File Panel

| Key       | Action                     |
|-----------|----------------------------|
| `<Space>` / `x` | Toggle file selection |
| `<CR>`    | Open side-by-side diff     |
| `l`       | Open side-by-side diff     |
| `a`       | Select all files           |
| `u`       | Deselect all files         |
| `R`       | Rollback file (with confirm) |
| `gf`      | Go to source file          |
| `o`       | Expand/collapse section    |

### Diff Panel

| Key       | Action                     |
|-----------|----------------------------|
| `]c`      | Next hunk (vim built-in)   |
| `[c`      | Previous hunk (vim built-in) |
| `s`       | Stage hunk                 |
| `R`       | Rollback hunk (with confirm) |
| `gf`      | Go to source line          |

### Commit Panel

| Key       | Action              |
|-----------|---------------------|
| `<C-a>`   | Toggle amend mode   |
| `<C-c>r`  | Commit              |
| `<C-c>p`  | Commit and push     |

## Configuration

Pass options to `setup()` to override any defaults:

```lua
require("commit-view").setup({
  file_panel_width = 0.25,     -- fraction of editor width
  commit_panel_height = 8,     -- lines

  icons = {
    checked   = "[x]",
    unchecked = "[ ]",
    modified  = "M",
    added     = "A",
    deleted   = "D",
    renamed   = "R",
    untracked = "?",
    section_open   = "",
    section_closed = "",
  },

  keymaps = {
    close            = "q",
    commit           = "<C-c>r",
    commit_and_push  = "<C-c>p",
    cycle_panel      = "<Tab>",
    cycle_panel_back = "<S-Tab>",
    help             = "?",
    -- file panel
    toggle_select     = "<Space>",
    toggle_select_alt = "x",
    open_diff         = "<CR>",
    open_diff_alt  = "l",
    select_all     = "a",
    deselect_all   = "u",
    rollback_file  = "R",
    goto_file      = "gf",
    toggle_section = "o",
    -- diff panel
    stage_hunk   = "s",
    unstage_hunk = "u",
    rollback_hunk = "R",
    toggle_hunk  = "<Space>",
    goto_source  = "gf",
    -- commit panel
    toggle_amend = "<C-a>",
  },
})
```

Set any keymap to `false` to disable it.

## How It Works

1. `:CommitView` opens a new tab with four panels: file list (left),
   old diff / new diff (top-right, side by side), and commit message (bottom).
2. Files are grouped into **Changes**, **Modified**, and **Unversioned Files**
   sections. Changed files are selected by default; unversioned files are not.
3. Press `<CR>` on a file to load a side-by-side diff using Neovim's native
   diff mode (`diffthis`, `scrollbind`, `cursorbind`).
4. From the diff panel you can stage or rollback individual hunks.
5. Type your commit message in the bottom panel. Toggle amend with `<C-a>`.
6. Press `<C-c>r` from any panel to commit, or `<C-c>p` to commit and push.
   At commit time the plugin runs `git add` on all selected files, then
   `git commit`.

## License

MIT
