-- workspaces.nvim: VS Code-style multi-root workspaces for Neovim.
-- Public API. Implementation lives in the submodules.
local M = {}

function M.setup(opts)
	local config = require("workspaces.config")
	config.setup(opts)
	if not pcall(require, "telescope") then
		require("workspaces.util").notify("telescope.nvim is required for the pickers.", vim.log.levels.WARN)
	end
	require("workspaces.keymaps").setup(config.options.keymaps)
	require("workspaces.autocmds").setup(config.options)
end

-- State ---------------------------------------------------------------------

function M.get_folders()
	return require("workspaces.state").folders
end

function M.get_active()
	return require("workspaces.state").active
end

-- Statusline text: "<name> (<folder count>)", or "" when no workspace is
-- active. Cheap enough to call on every statusline redraw.
function M.statusline()
	local state = require("workspaces.state")
	if not state.active then
		return ""
	end
	return state.active .. " (" .. #state.folders .. ")"
end

-- Workspaces ----------------------------------------------------------------

function M.new_workspace()
	require("workspaces.session").new()
end

function M.open_workspace()
	require("workspaces.ui.workspace_picker").open()
end

-- With a name: confirm + delete it. Without: open the delete picker.
function M.delete_workspace(name)
	if type(name) == "string" and name ~= "" then
		require("workspaces.ui.delete_picker").delete(name)
	else
		require("workspaces.ui.delete_picker").open()
	end
end

function M.save_current_workspace()
	require("workspaces.session").save({ verbose = true })
end

-- Folders -------------------------------------------------------------------

-- With a path: add it directly. Without: open the folder picker.
function M.add_folder(path)
	if type(path) == "string" and path ~= "" then
		require("workspaces.folders").add(path)
	else
		require("workspaces.ui.folder_picker").open()
	end
end

function M.delete_folder()
	require("workspaces.ui.remove_folder_picker").open()
end

-- Search (Telescope) --------------------------------------------------------

function M.find_files()
	require("workspaces.integrations.telescope").find_files()
end

function M.live_grep()
	require("workspaces.integrations.telescope").live_grep()
end

function M.grep_string()
	require("workspaces.integrations.telescope").grep_string()
end

function M.grep_with_mods()
	require("workspaces.integrations.telescope").grep_with_mods()
end

-- Pick folders (workspace folders + subdirs), then supercharged grep only those.
function M.grep_with_mods_nitpicky()
	require("workspaces.ui.nitpicky_picker").open()
end

-- Plain supercharged grep (cwd-only, ignores workspace folders), like the
-- original telescope_addons `<leader>fcg`. Accepts { cwd = ..., search_dirs = {...} }.
function M.multigrep(opts)
	require("workspaces.integrations.multigrep").open(opts)
end

function M.oldfiles()
	require("workspaces.integrations.telescope").oldfiles()
end

-- Git -----------------------------------------------------------------------

function M.neogit()
	require("workspaces.integrations.git").neogit()
end

function M.git_changes()
	require("workspaces.integrations.git_changes").open()
end

-- For Harpoon 2's settings.key: one list per workspace; cwd (Harpoon's
-- default) when no workspace is active or `integrations.harpoon` is false.
function M.harpoon_key()
	local active = require("workspaces.state").active
	if active and require("workspaces.config").integration("harpoon") then
		return "workspace:" .. active
	end
	return (vim.uv or vim.loop).cwd()
end

function M.git_worktrees()
	require("workspaces.integrations.git").worktrees()
end

function M.create_git_worktree()
	require("workspaces.integrations.git").create_worktree()
end

-- nvim-tree -----------------------------------------------------------------

-- Use as nvim-tree's `filters = { custom = require("workspaces").nvim_tree_filter }`.
-- Hides nothing (false) when `integrations.nvim_tree` is false.
function M.nvim_tree_filter(absolute_path)
	return require("workspaces.integrations.nvim_tree").filter(absolute_path)
end

return M
