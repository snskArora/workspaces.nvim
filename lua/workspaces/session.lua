-- Workspace lifecycle: save, create, switch, delete.
local config = require("workspaces.config")
local state = require("workspaces.state")
local storage = require("workspaces.storage")
local util = require("workspaces.util")
local tree = require("workspaces.integrations.nvim_tree")

local M = {}

local function lsp_sync()
	require("workspaces.integrations.lsp").sync()
end

-- Save the active workspace: `:wall` (optional), mksession, folder list.
-- Errors are reported, never thrown.
--   opts.verbose      notify on success (explicit :WorkspaceSave)
--   opts.exiting      Neovim is quitting: don't reopen the tree
--   opts.reopen_tree  false = leave the tree closed and return the function
--                     that reopens it (callers that wipe buffers next)
-- Returns a function that reopens the tree, or nil when there is nothing to reopen.
function M.save(opts)
	opts = opts or {}
	if not state.active then
		return nil
	end
	if config.options.autosave.write_buffers then
		-- Flush modified buffers so the session doesn't only remember layout
		-- while silently discarding unsaved edits.
		vim.cmd("silent! wall")
	end
	local restore_tree = tree.close_for_session()
	local file = storage.session_file(state.active)
	local ok, err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(file))
	if restore_tree and opts.reopen_tree ~= false and not opts.exiting then
		restore_tree()
		restore_tree = nil
	end
	if not ok then
		util.notify("Could not save session " .. file .. ": " .. tostring(err), vim.log.levels.ERROR)
	elseif storage.write_folders(state.active, state.folders) and opts.verbose then
		util.notify("Saved workspace: " .. state.active)
	end
	return restore_tree
end

-- Wipe every buffer and forget the active workspace. Buffers were already
-- flushed to disk by save(). The tree is closed first so the wipe never pulls
-- its buffer out from under nvim-tree; returns the function that reopens it.
local function clear()
	local restore_tree = tree.close_for_session()
	pcall(vim.cmd, "silent! %bd!")
	state.folders = {}
	state.active = nil
	return restore_tree
end

function M.create(name)
	local ok, err = storage.valid_name(name)
	if not ok then
		util.notify(err, vim.log.levels.WARN)
		return
	end
	local restore_tree = M.save({ reopen_tree = false })
	restore_tree = clear() or restore_tree
	state.active = name
	M.save() -- write the session files right away
	if restore_tree then
		restore_tree()
	end
	lsp_sync()
	util.notify("Created and entered workspace: " .. name)
end

function M.switch(name)
	if not storage.exists(name) then
		util.notify("No such workspace: " .. tostring(name), vim.log.levels.WARN)
		return
	end
	local restore_tree = M.save({ reopen_tree = false })
	restore_tree = clear() or restore_tree
	state.active = name
	-- `silent!` keeps sourcing past errors in the session (e.g. a cwd or file
	-- that no longer exists), so windows and buffers still come back.
	pcall(vim.cmd, "silent! source " .. vim.fn.fnameescape(storage.session_file(name)))
	tree.clean_session_buffers()
	state.folders = storage.read_folders(name)
	util.follow_root(state.folders) -- overrides the cwd stored in the session
	if #state.folders > 0 then
		tree.sync(state.folders)
	elseif restore_tree then
		restore_tree()
	end
	lsp_sync()
	util.notify("Switched to workspace: " .. name)
end

-- y/N confirmation on the command line; only "y"/"yes" (any case) confirms.
function M.confirm_delete(name)
	local answer = vim.fn.input("Delete workspace '" .. name .. "'? (y/N): ")
	vim.cmd("redraw")
	return answer:lower():match("^y") ~= nil
end

-- Delete a workspace's files. Deleting the active one leaves you in
-- no-workspace mode (files written, buffers wiped, empty state); the caller
-- decides what to open next. Returns: deleted (bool), was_active (bool).
function M.delete(name)
	if not storage.valid_name(name) then
		return false, false
	end
	local was_active = name == state.active
	if was_active then
		state.active = nil -- so nothing re-saves the deleted session
		if config.options.autosave.write_buffers then
			vim.cmd("silent! wall")
		end
		local restore_tree = clear()
		if restore_tree then
			restore_tree()
		end
		lsp_sync()
	end
	local ok = storage.delete(name)
	if ok then
		util.notify("Deleted workspace: " .. name)
	else
		util.notify("Could not delete workspace: " .. name, vim.log.levels.ERROR)
	end
	return ok, was_active
end

-- Name popup, then create. Invalid or existing names warn and keep the popup open.
function M.new()
	require("workspaces.ui.name_prompt").ask({
		title = "New workspace name",
		legend = "<CR> create · Esc cancel",
		validate = function(name)
			local ok, err = storage.valid_name(name)
			if not ok then
				return err
			end
			if storage.exists(name) then
				return "Workspace '" .. name .. "' already exists."
			end
		end,
		on_submit = M.create,
	})
end

return M
