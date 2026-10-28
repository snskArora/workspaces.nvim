-- nvim-tree integration (optional: everything is a no-op without nvim-tree,
-- or with `integrations.nvim_tree = false`, in which case nvim-tree is never
-- even required).
local config = require("workspaces.config")
local state = require("workspaces.state")
local util = require("workspaces.util")

local M = {}

-- For nvim-tree's `filters.custom`. With 2+ folders, hide every path that
-- isn't a workspace folder, inside one, or an ancestor needed to reach one,
-- so the tree (rooted at their common ancestor) only shows your folders.
-- Hides nothing when the integration is off.
function M.filter(absolute_path)
	local folders = state.folders
	if #folders <= 1 or not config.integration("nvim_tree") then
		return false
	end
	for _, folder in ipairs(folders) do
		local clean = folder:gsub("/$", "")
		if
			absolute_path == clean
			or vim.startswith(absolute_path, clean .. "/") -- inside a folder
			or vim.startswith(clean, absolute_path .. "/") -- ancestor of one
		then
			return false
		end
	end
	return true
end

local function api()
	if not config.integration("nvim_tree") then
		return nil
	end
	local ok, a = pcall(require, "nvim-tree.api")
	return ok and a or nil
end

local function is_tree_win(win)
	return vim.api.nvim_win_is_valid(win) and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree"
end

-- Give focus back to `win` unless it was the tree (which was recreated).
local function refocus(win)
	if is_tree_win(win) then
		return
	end
	if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() ~= win then
		pcall(vim.api.nvim_set_current_win, win)
	end
end

-- Sessions: mksession would store the tree window as a dead "NvimTree_N"
-- buffer. Close the tree around the save and reopen it afterwards.
-- Returns a function that reopens the tree, or nil if it wasn't open.
function M.close_for_session()
	local a = api()
	if not (a and a.tree.is_visible()) then
		return nil
	end
	local win = vim.api.nvim_get_current_win()
	pcall(a.tree.close_in_all_tabs or a.tree.close)
	return function()
		pcall(a.tree.open)
		refocus(win)
	end
end

-- After sourcing a session: wipe dead NvimTree buffers (older sessions).
function M.clean_session_buffers()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(buf):match("NvimTree_%d+$") then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
end

-- Last folder removed: put a visible tree back on the cwd.
function M.reset_root()
	local a = api()
	if a and a.tree.is_visible() then
		M.sync(vim.fn.getcwd(-1, -1))
	end
end

-- Re-root the tree on a path, or on the common ancestor of a list of paths.
-- Opens the tree if needed; focus stays where it was; no cwd changes.
function M.sync(target)
	if not target then
		return
	end
	local path = type(target) == "table" and util.common_ancestor(target) or target
	local a = api()
	if not (path and a) then
		return
	end
	local win = vim.api.nvim_get_current_win()
	local global_cwd = vim.fn.getcwd(-1, -1)
	pcall(function()
		-- change_root is a no-op until the explorer exists, which only happens
		-- once the tree has been opened. open() is idempotent.
		a.tree.open()
		a.tree.change_root(path)
		a.tree.reload()
	end)
	-- nvim-tree `:lcd`s its window into the new root (actions.change_dir).
	-- Undo that so re-rooting never changes any cwd: `:cd` inside a window
	-- clears its window-local directory.
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if is_tree_win(w) and vim.fn.haslocaldir(w) == 1 then
			vim.api.nvim_win_call(w, function()
				pcall(vim.cmd, "noautocmd cd " .. vim.fn.fnameescape(global_cwd))
			end)
		end
	end
	refocus(win)
end

return M
