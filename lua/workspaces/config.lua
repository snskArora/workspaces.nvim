-- Default options and the merged, active configuration.
local M = {}

M.defaults = {
	-- Where `<name>.vim` (mksession) and `<name>.json` (folder list) live.
	-- Created 0700: session files are executed with :source when opened.
	session_dir = vim.fn.stdpath("data") .. "/workspaces/",

	-- `:cd` to the common root of the workspace folders on every switch and
	-- folder add/remove ("/" if they share nothing; unchanged with 0 folders).
	cwd_follows_root = true,

	-- Open the workspace picker on a clean interactive launch (no file args,
	-- no `nvim -S`, nothing piped in, not headless).
	startup_picker = true,

	autosave = {
		on_exit = true, -- save the active workspace on VimLeavePre
		write_buffers = true, -- `:wall` before saving so unsaved edits aren't lost
	},

	-- Directory picker used by "add folder".
	folder_picker = {
		max_depth = 4, -- only limits the picker scan; searches stay unrestricted
		exclude = { ".git", "node_modules", "target", "dist" },
		browse_depth = 2, -- levels listed per directory in browse mode (<C-o>)
	},

	-- Folder picker for grep_with_mods_nitpicky (<leader>fns). Scans workspace
	-- folders + all subdirs (hidden included, .gitignore not respected).
	grep_with_mods_nitpicky = {
		include_excluded = false, -- true = also list folder_picker.exclude dirs
		toggle_key = "<C-e>", -- in-picker toggle for the above (rest of session)
		max_depth = nil, -- nil = unlimited; set on slow machines
		max_results = nil, -- nil = unlimited; stop scanning after N dirs
	},

	-- Register workspace folders with LSP servers that support
	-- workspaceFolders. servers = nil means every such server; or a list of
	-- names, e.g. { "lua_ls" }. Each registered folder gets indexed.
	lsp = {
		enabled = true,
		servers = nil,
	},

	-- Every external plugin integration is on by default and can be switched
	-- off on its own. Off means the plugin never calls into that plugin: its
	-- default keymaps are not registered, the Lua API warns, and the hooks your
	-- config calls (harpoon_key, nvim_tree_filter) fall back to stock behaviour.
	-- Telescope is required and has no switch; LSP is `lsp.enabled` above.
	integrations = {
		nvim_tree = true, -- re-rooting, filter, session-safe saves
		neogit = true, -- <leader>gt routing
		git_worktree = true, -- <leader>gwt / <leader>gwa workspace mode
		harpoon = true, -- harpoon_key() per-workspace lists
	},

	-- Set the whole table to false to skip all keymaps, or a single entry to
	-- false to skip just that one.
	keymaps = {
		new_workspace = "<leader>wn",
		open_workspace = "<leader>wo",
		add_folder = "<leader>wa",
		delete_folder = "<leader>wd",
		delete_workspace = "<leader>wD",
		find_files = "<leader>ff",
		oldfiles = "<leader>fr",
		grep_with_mods = "<leader>fs", -- supercharged grep across workspace folders
		multigrep = "<leader>fcg", -- supercharged grep in cwd only
		grep_with_mods_nitpicky = "<leader>fns", -- supercharged grep in picked folders
		live_grep = "<leader>feus",
		grep_string = "<leader>grep",
		neogit = "<leader>gt",
		git_changes = "<leader>gs", -- changed files across all workspace repos
		git_worktrees = "<leader>gwt",
		create_git_worktree = "<leader>gwa",
	},
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
	if opts ~= nil and type(opts) ~= "table" then
		error("workspaces.setup: expected a table, got " .. type(opts))
	end
	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
	local dir = M.options.session_dir
	if type(dir) ~= "string" or dir == "" then
		dir = M.defaults.session_dir
	end
	dir = vim.fn.fnamemodify(vim.fs.normalize(dir), ":p")
	M.options.session_dir = dir:match("/$") and dir or dir .. "/"
	-- tables the scanners iterate over must stay tables
	for _, key in ipairs({ "folder_picker", "grep_with_mods_nitpicky", "autosave", "integrations" }) do
		if type(M.options[key]) ~= "table" then
			M.options[key] = vim.deepcopy(M.defaults[key])
		end
	end
	if type(M.options.folder_picker.exclude) ~= "table" then
		M.options.folder_picker.exclude = {}
	end
end

-- Is the integration `name` (a key of `integrations`) switched on? Only an
-- explicit `false` turns one off, so unknown or missing keys read as on.
function M.integration(name)
	local i = M.options.integrations
	return type(i) ~= "table" or i[name] ~= false
end

return M
