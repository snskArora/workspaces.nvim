-- Auto-sourced by Neovim. Only defines user commands; behaviour (keymaps,
-- autocmds) is opt-in via require("workspaces").setup().
if vim.g.loaded_workspaces then
	return
end
vim.g.loaded_workspaces = true

local function cmd(name, fn, opts)
	vim.api.nvim_create_user_command(name, fn, opts or {})
end

cmd("WorkspaceNew", function()
	require("workspaces").new_workspace()
end, { desc = "Create a new workspace" })

cmd("WorkspaceOpen", function()
	require("workspaces").open_workspace()
end, { desc = "Open/switch workspace" })

cmd("WorkspaceDelete", function(args)
	require("workspaces").delete_workspace(args.args)
end, {
	nargs = "?",
	complete = function(lead)
		return vim.tbl_filter(function(n)
			return vim.startswith(n, lead)
		end, require("workspaces.storage").list())
	end,
	desc = "Delete a workspace (picker if no name given)",
})

cmd("WorkspaceSave", function()
	require("workspaces").save_current_workspace()
end, { desc = "Save the active workspace" })

cmd("WorkspaceAddFolder", function(args)
	require("workspaces").add_folder(args.args)
end, { nargs = "?", complete = "dir", desc = "Add a folder (picker if no path given)" })

cmd("WorkspaceGrep", function()
	require("workspaces").grep_with_mods()
end, { desc = "Supercharged grep (pattern |:| globs) across workspace folders" })

cmd("WorkspaceGrepSelective", function()
	require("workspaces").grep_with_mods_nitpicky()
end, { desc = "Pick folders, then supercharged grep only those" })

cmd("WorkspaceRemoveFolder", function()
	require("workspaces").delete_folder()
end, { desc = "Remove folders from the workspace (multi-select picker)" })
