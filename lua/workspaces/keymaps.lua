local M = {}

-- action name (matches config.keymaps keys) -> { function, description,
-- integration it needs (its keymap is skipped when that integration is off) }
local function actions()
	local ws = require("workspaces")
	return {
		new_workspace = { ws.new_workspace, "Save workspace & start a new empty one" },
		open_workspace = { ws.open_workspace, "Open/switch workspace session" },
		add_folder = { ws.add_folder, "Add folder to workspace" },
		delete_folder = { ws.delete_folder, "Remove folder from workspace" },
		delete_workspace = {
			function()
				ws.delete_workspace()
			end,
			"Delete a workspace",
		},
		find_files = { ws.find_files, "Fuzzy find files (multi-root aware)" },
		oldfiles = { ws.oldfiles, "Fuzzy find recent files (multi-root aware)" },
		grep_with_mods = { ws.grep_with_mods, "Find in workspace with mods (multi-root aware)" },
		grep_with_mods_nitpicky = { ws.grep_with_mods_nitpicky, "Find with mods in selected folders" },
		multigrep = {
			function()
				ws.multigrep()
			end,
			"Supercharged grep in cwd",
		},
		live_grep = { ws.live_grep, "Live grep (multi-root aware)" },
		grep_string = { ws.grep_string, "Find string under cursor (multi-root aware)" },
		neogit = { ws.neogit, "Open Neogit (multi-root aware)", "neogit" },
		git_changes = { ws.git_changes, "Changed files across workspace repos" },
		git_worktrees = { ws.git_worktrees, "Show git worktrees (multi-root aware)", "git_worktree" },
		create_git_worktree = { ws.create_git_worktree, "Create a git worktree (multi-root aware)", "git_worktree" },
	}
end

function M.setup(maps)
	if type(maps) ~= "table" then
		return
	end
	local config = require("workspaces.config")
	for name, action in pairs(actions()) do
		local lhs = maps[name]
		local wanted = not action[3] or config.integration(action[3])
		if wanted and type(lhs) == "string" and lhs ~= "" then
			vim.keymap.set("n", lhs, action[1], { desc = action[2] })
		end
	end
end

return M
