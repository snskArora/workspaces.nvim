# workspaces.nvim

Multi-root workspaces for Neovim, in the spirit of VS Code's `.code-workspace` files. A workspace is a name, any number of folders (they don't need to share a parent), and a saved session. Searching, the file tree, git tooling, LSP workspace folders and Harpoon lists all follow the workspace instead of a single `cwd`.

Built for [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim), with optional integrations for [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua), [neogit](https://github.com/NeogitOrg/neogit), [git-worktree.nvim](https://github.com/ThePrimeagen/git-worktree.nvim), [harpoon](https://github.com/ThePrimeagen/harpoon/tree/harpoon2) (v2), the built-in LSP client and any statusline.

## Features

- **Named workspaces with sessions.** Create, open, switch and delete workspaces from Telescope pickers. Each one keeps its windows, buffers and layout through `:mksession`, saved automatically on every change and on exit.
- **Any folders, anywhere.** Add folders with a scanning picker, a browse mode that walks the filesystem, or by typing a path. Remove several at once.
- **Workspace-wide search.** Find files, recent files, live grep and grep-under-cursor across every folder. A ripgrep picker takes `pattern |:| glob, glob`, either across all folders or across folders and subfolders you pick.
- **The cwd follows the workspace.** Neovim's working directory is always the common root of the folders, so everything that reads `cwd` keeps working.
- **A file tree that only shows your folders.** nvim-tree is rooted at the common ancestor and filtered down to the workspace folders, without changing any directory and without stealing focus.
- **Git across repositories.** Neogit opens in the current file's repository or offers a picker showing branch and change counts. One picker lists changed files from every repository with a diff preview. git-worktree creation, listing and deletion manage workspace folders instead of changing directories.
- **LSP and Harpoon awareness.** Workspace folders are registered with language servers that support them, and Harpoon can keep one list per workspace.
- **Light and safe.** Pure Lua, no shell, asynchronous scans that are killed when a picker closes, cached tool lookups, folder lists stored as JSON, validated workspace names, and a private (0700) session directory. Designed to run on small remote hosts.

## Requirements

- Neovim 0.10 or newer.
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) and [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).
- [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) for the grep pickers.
- Optional: [fd](https://github.com/sharkdp/fd) (`fd` or `fdfind`) for faster folder scans; `find` is used otherwise.
- Optional integrations: nvim-tree.lua, neogit, git-worktree.nvim, harpoon (harpoon2 branch), a statusline plugin.

The Lua module is `workspaces`, which collides with [natecraddock/workspaces.nvim](https://github.com/natecraddock/workspaces.nvim). Don't install both.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  dir = "snskArora/workspaces.nvim", -- replace with "<user>/workspaces.nvim" once published
  dependencies = { "nvim-telescope/telescope.nvim" },
  lazy = false, -- the startup picker hooks VimEnter, so setup() must run before it
  opts = {},
}
```

`opts` is passed to `require("workspaces").setup()`. Every option has a default (see [Configuration](#configuration)), so `opts = {}` is a complete installation.

## Quick start

1. Start `nvim` with no arguments. The workspace picker opens; choose `[New Workspace]` and type a name.
2. Press `<leader>wa` and pick a folder, or use `<C-o>` to browse, or run `:WorkspaceAddFolder ~/src/app`. Repeat for every folder you want in the workspace.
3. Search with `<leader>ff`, `<leader>fs` or `<leader>feus`. Open git with `<leader>gt`, see changes with `<leader>gs`.
4. Switch workspaces with `<leader>wo`. Your layout comes back, the cwd moves to the new common root, and the tree, LSP and Harpoon follow.

Everything is saved as you go. Quitting Neovim saves the active workspace too.

## Commands

| Command | Action |
| --- | --- |
| `:WorkspaceNew` | Save the current workspace and create a new, empty one (name popup) |
| `:WorkspaceOpen` | Pick a workspace to switch to |
| `:WorkspaceSave` | Save the active workspace now |
| `:WorkspaceDelete [name]` | Delete a workspace; a picker when no name is given (names tab-complete) |
| `:WorkspaceAddFolder [dir]` | Add a folder; a picker when no path is given (directories tab-complete) |
| `:WorkspaceRemoveFolder` | Remove folders with a multi-select picker |
| `:WorkspaceGrep` | ripgrep picker across every workspace folder |
| `:WorkspaceGrepSelective` | Pick folders and subfolders first, then run the ripgrep picker on them |

## Default keymaps

All keymaps are normal-mode and configurable through `keymaps` (see [Configuration](#configuration)).

| Key | Action |
| --- | --- |
| `<leader>wn` | New workspace |
| `<leader>wo` | Open or switch workspace |
| `<leader>wD` | Delete a workspace |
| `<leader>wa` | Add a folder |
| `<leader>wd` | Remove folders |
| `<leader>ff` | Find files in the workspace |
| `<leader>fr` | Recent files in the workspace |
| `<leader>feus` | Live grep in the workspace |
| `<leader>grep` | Grep the word under the cursor in the workspace |
| `<leader>fs` | ripgrep picker across all folders (`pattern \|:\| glob, glob`) |
| `<leader>fns` | ripgrep picker across folders you pick |
| `<leader>fcg` | ripgrep picker in the cwd only |
| `<leader>gt` | Neogit for the current file's repository, or a repository picker |
| `<leader>gs` | Changed files across all workspace repositories |
| `<leader>gwt` | Git worktrees (inside a workspace, selecting one adds it as a folder) |
| `<leader>gwa` | Create a git worktree (inside a workspace, it is added as a folder) |

With no workspace folders, every search falls back to the plain Telescope builtin on the cwd.

## Pickers

Each picker shows its keys in the title of its results window.

| Picker | Keys |
| --- | --- |
| Open workspace (`<leader>wo`) | `<CR>` open, `<C-d>` delete the highlighted workspace after a confirmation popup. The preview shows when the workspace was last saved and its folders; folders that no longer exist are flagged `[missing]`. |
| Delete workspace (`<leader>wD`) | `<CR>` opens the confirmation popup. Deleting the active workspace leaves you with no workspace and offers the picker to open another. |
| Confirmation popup | `No, keep it` is highlighted by default; `<CR>` chooses, `Esc` keeps. `:WorkspaceDelete <name>` asks on the command line instead. |
| New workspace name | A one-line popup: `<CR>` creates, `Esc` cancels. Invalid or existing names warn and keep the popup open. |
| Add folder, normal mode (`<leader>wa`) | Lists directories under the cwd up to `folder_picker.max_depth`. `<CR>` adds the highlighted directory (or the typed path when nothing matches), `<C-y>` adds the typed path, `<C-o>` switches to browse mode. |
| Add folder, browse mode | Lists the current directory to `folder_picker.browse_depth` levels plus `../` and `../../`. `<Tab>` moves in or out, `<CR>` adds (on `../` it moves up), `<C-y>` adds the typed path, `<C-o>` returns to normal mode. The mode is remembered for the session. |
| Remove folders (`<leader>wd`) | `<Tab>` or `<CR>` mark, `<C-s>` removes every marked folder without confirmation, `Esc` cancels. |
| Folders to grep (`<leader>fns`) | Workspace folders and all their subfolders. `<Tab>` marks, `<CR>` runs the grep on the marked folders, `<C-e>` shows or hides the excluded directories. The last selection is pre-marked next time. |
| Repository picker | `<CR>` selects. Entries read `work/app/ (main, 3 changed)`; the counts fill in asynchronously. |
| Changed files (`<leader>gs`) | `<CR>` opens the file. Entries carry git's two-letter status; the preview is `git diff HEAD` for that file. |
| Worktree list (`<leader>gwt`) | `<CR>` adds the worktree as a folder (switches to it outside a workspace), `<C-d>` deletes it and removes its folder, `<C-f>` forces the next deletion. |

The ripgrep prompt is `pattern |:| glob, glob`. For example `TODO |:| *.lua, !**/tests/**` searches Lua files outside `tests` directories.

## Configuration

Defaults, as passed to `setup()`:

```lua
require("workspaces").setup({
  -- Where sessions and folder lists live. Created with mode 0700.
  session_dir = vim.fn.stdpath("data") .. "/workspaces/",

  -- :cd to the common root of the folders on every switch and folder change ("/" when they share nothing; unchanged with no folders).
  cwd_follows_root = true,

  -- Open the workspace picker on a clean interactive launch (no arguments, no -S, nothing piped in, not headless).
  startup_picker = true,

  autosave = {
    on_exit = true,       -- save the active workspace when Neovim exits
    write_buffers = true, -- :wall before every save so unsaved edits are kept
  },

  folder_picker = {
    max_depth = 4,                                          -- scan depth of the add-folder picker
    exclude = { ".git", "node_modules", "target", "dist" }, -- directory names skipped by every scan
    browse_depth = 2,                                       -- levels listed per directory in browse mode
  },

  grep_with_mods_nitpicky = {
    include_excluded = false, -- also list the excluded directories
    toggle_key = "<C-e>",     -- key that toggles the above inside the picker
    max_depth = nil,          -- nil = unlimited
    max_results = nil,        -- nil = unlimited; stop the scan after N directories
  },

  -- Register workspace folders with LSP servers that support workspaceFolders. servers = nil means every such server.
  lsp = { enabled = true, servers = nil },

  -- Every external plugin integration is on by default; set one to false and the plugin never calls into that plugin (see Integrations).
  integrations = {
    nvim_tree = true,    -- re-rooting, filter, closing the tree around session saves
    neogit = true,       -- <leader>gt repo routing
    git_worktree = true, -- <leader>gwt / <leader>gwa workspace mode
    harpoon = true,      -- harpoon_key() per-workspace lists
  },

  -- Set the table to false for no keymaps, or an entry to false to skip that one.
  keymaps = {
    new_workspace = "<leader>wn",  open_workspace = "<leader>wo",  delete_workspace = "<leader>wD",
    add_folder = "<leader>wa",     delete_folder = "<leader>wd",
    find_files = "<leader>ff",     oldfiles = "<leader>fr",        live_grep = "<leader>feus",
    grep_string = "<leader>grep",  grep_with_mods = "<leader>fs",  grep_with_mods_nitpicky = "<leader>fns",
    multigrep = "<leader>fcg",
    neogit = "<leader>gt",         git_changes = "<leader>gs",
    git_worktrees = "<leader>gwt", create_git_worktree = "<leader>gwa",
  },
})
```

On machines with slow disks or CPUs, set `grep_with_mods_nitpicky.max_depth` or `max_results` to bound the subfolder scan, and consider `lsp.servers` to limit which servers index every folder.

## Integrations

workspaces.nvim works on its own. The following edits to other plugins' configurations enable the integrations; each one is independent.

Every integration is on by default and has its own switch in the `integrations` table. Set one to `false` and the plugin never calls into that plugin: its default keymaps are not registered, calling its Lua API warns, and the hooks your own config calls (`harpoon_key`, `nvim_tree_filter`) fall back to stock behaviour, so those snippets can stay in place. Telescope is required and has no switch; LSP is controlled by `lsp.enabled`.

| Switch | Turns off |
| --- | --- |
| `integrations.nvim_tree` | Re-rooting, root reset, the `nvim_tree_filter` hook (returns `false`), and closing the tree around session saves. nvim-tree is never required. |
| `integrations.neogit` | The `<leader>gt` keymap and repo routing. |
| `integrations.git_worktree` | The `<leader>gwt` / `<leader>gwa` keymaps and the workspace-mode wrappers; git-worktree.nvim behaves as upstream everywhere. |
| `integrations.harpoon` | Per-workspace Harpoon lists; `harpoon_key()` returns the cwd. |
| `lsp.enabled` | Registering workspace folders with language servers. |

### Keymaps that clash

The plugin maps `<leader>ff`, `fr`, `fs`, `feus`, `grep`, `gt`, `gwt` and `gwa` by default. Remove your own mappings for those keys, or turn ours off individually:

```lua
opts = { keymaps = { find_files = false, neogit = false } }
```

### nvim-tree

nvim-tree reads filters only from its own `setup()`, so add this to your nvim-tree configuration to hide directories that aren't in the workspace:

```lua
filters = {
  custom = function(path)
    local ok, ws = pcall(require, "workspaces")
    return ok and ws.nvim_tree_filter(path) or false
  end,
},
```

Without it the tree still re-roots to the common ancestor of your folders, but also shows their siblings.

With `integrations = { nvim_tree = false }` the plugin leaves the tree alone entirely. One consequence: the tree is then no longer closed around `:mksession`, so a session saved while the tree is open records a dead `NvimTree_N` buffer. The plugin still wipes such buffers after loading a session.

### git-worktree.nvim

Keep its setup and Telescope extension loaded; nothing else is needed:

```lua
require("git-worktree").setup()
require("telescope").load_extension("git_worktree")
```

Inside a workspace the plugin wraps git-worktree's create, switch and delete so worktrees become workspace folders and the working directory never changes. Outside a workspace, or with `integrations = { git_worktree = false }`, git-worktree behaves exactly as upstream and the wrappers are never installed.

### Harpoon (harpoon2)

One Harpoon list per workspace, falling back to Harpoon's cwd-based lists when no workspace is active:

```lua
harpoon:setup({
  settings = {
    key = function()
      local ok, ws = pcall(require, "workspaces")
      return ok and ws.harpoon_key() or vim.uv.cwd()
    end,
  },
})
```

Existing cwd-keyed lists are not shown inside a workspace; they return when no workspace is active, or always with `integrations = { harpoon = false }`.

### Statusline

`require("workspaces").statusline()` returns `"<name> (<folder count>)"`, or an empty string when no workspace is active. Add it as a component of your statusline, for example in lualine:

```lua
lualine_b = {
  function()
    local ok, ws = pcall(require, "workspaces")
    return ok and ws.statusline() or ""
  end,
  "branch",
},
```

### LSP

Nothing to configure. Folders are registered with every running server that advertises `workspaceFolders` support (for example lua_ls, pyright, terraformls, yamlls) and unregistered when removed; a server's own root folder is never touched. Restrict it with `lsp = { servers = { "lua_ls" } }` or disable it with `lsp = { enabled = false }`.

## Lua API

```lua
local ws = require("workspaces")
ws.get_active()                 -- active workspace name or nil
ws.get_folders()                -- list of folders, each ending in "/"
ws.statusline()                 -- "<name> (<count>)" or ""
ws.harpoon_key()                -- "workspace:<name>", or the cwd (no workspace, or integrations.harpoon = false)
ws.nvim_tree_filter(path)       -- true when nvim-tree should hide `path`; false when integrations.nvim_tree = false
ws.add_folder(path)             -- add a folder; opens the picker when path is nil
ws.multigrep({ cwd = ..., search_dirs = { ... } }) -- the ripgrep picker on arbitrary directories
```

The functions behind every command and keymap are exported too: `new_workspace`, `open_workspace`, `delete_workspace(name)`, `save_current_workspace`, `delete_folder`, `find_files`, `oldfiles`, `live_grep`, `grep_string`, `grep_with_mods`, `grep_with_mods_nitpicky`, `neogit`, `git_changes`, `git_worktrees`, `create_git_worktree`. The last three for Neogit and git-worktree warn and do nothing when their integration is switched off.

## Storage and security

Everything lives in `session_dir`:

| File | Content |
| --- | --- |
| `<name>.vim` | The `:mksession` output. It is Vimscript and is executed with `:source` when the workspace opens. |
| `<name>.json` | The folder list, plain JSON. Read with `vim.json.decode`, never executed. |

Folder lists written by early versions (`<name>.vars.lua`) are converted to JSON the first time they are read, without executing them.

Because session files are executed, anyone who can write to `session_dir` can run code in your editor. The directory is created with mode 0700 and defaults to a location under `stdpath("data")`; if you point it at a synced or shared folder, trust it accordingly. Workspace names are validated so they can never form a path outside `session_dir`. The plugin never invokes a shell; external tools (`rg`, `fd`, `find`, `git`) receive argument lists.

## Behaviour notes

- A workspace must be active before folders can be added. With no active workspace the searches use the cwd and nothing is saved.
- Switching workspaces writes all modified buffers (`autosave.write_buffers`) and then wipes every buffer, including terminals. Unnamed buffers cannot be written and are lost.
- When folders share no common ancestor the cwd becomes `/`. Searches are unaffected since they use the folder list.
- nvim-tree shows one root, so a workspace with folders in unrelated locations is displayed under their common ancestor, filtered to the workspace folders.
- The Telescope previewers need about 120 columns to appear in the default layout.

## Project layout

```
plugin/workspaces.lua            user commands only; no side effects on load
lua/workspaces/
  init.lua                       public API and setup()
  config.lua                     defaults and option validation
  state.lua                      active workspace and folder list
  storage.lua                    session dir, JSON folder files, legacy migration, name validation
  session.lua                    save, create, switch, delete
  folders.lua                    add and remove folders
  keymaps.lua, autocmds.lua, util.lua
  ui/                            Telescope pickers and popups
  integrations/telescope.lua     multi-root find, grep and recent files
  integrations/multigrep.lua     the ripgrep pattern + glob picker
  integrations/nvim_tree.lua     root sync, filter, session-safe saves
  integrations/git.lua           Neogit routing and git-worktree workspace mode
  integrations/git_repos.lua     repository discovery and the repository picker
  integrations/git_changes.lua   changed files across repositories
  integrations/lsp.lua           workspace folders for language servers
```
