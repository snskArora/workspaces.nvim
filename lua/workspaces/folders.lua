-- Adding/removing folders in the active workspace.
local state = require("workspaces.state")
local util = require("workspaces.util")
local tree = require("workspaces.integrations.nvim_tree")

local M = {}

-- cwd follows the folders, the session is saved (with the tree closed so the
-- session never records it), then the tree is re-rooted or reopened.
local function after_change()
	util.follow_root(state.folders)
	local restore_tree = require("workspaces.session").save({ reopen_tree = false })
	if #state.folders > 0 then
		tree.sync(state.folders)
	else
		if restore_tree then
			restore_tree()
		end
		tree.reset_root()
	end
	require("workspaces.integrations.lsp").sync()
end

-- Validate, dedupe and register a folder path (picked or typed).
function M.add(raw)
	if not state.active then
		util.notify("No active workspace. Create or open one first (<leader>wn / <leader>wo).", vim.log.levels.WARN)
		return
	end
	local dir = util.normalize_dir(raw)
	if not dir then
		if raw and vim.trim(raw) ~= "" then
			util.notify("Not a valid directory: " .. raw, vim.log.levels.WARN)
		end
		return
	end
	if vim.tbl_contains(state.folders, dir) then
		util.notify("Folder is already in the workspace!")
		return
	end
	table.insert(state.folders, dir)
	util.notify("Added to workspace: " .. dir)
	after_change()
end

-- Remove several folders at once (one tree sync + one save).
function M.remove_many(paths)
	local drop = {}
	for _, p in ipairs(paths) do
		drop[p] = true
	end
	local kept, removed = {}, {}
	for _, f in ipairs(state.folders) do
		table.insert(drop[f] and removed or kept, f)
	end
	if #removed == 0 then
		return
	end
	state.folders = kept
	util.notify("Removed from workspace: " .. table.concat(removed, ", "))
	after_change()
end

return M
