-- Telescope picker for deleting a workspace (<leader>wD, :WorkspaceDelete).
local storage = require("workspaces.storage")
local session = require("workspaces.session")
local util = require("workspaces.util")

local M = {}

-- Delete one confirmed workspace. If it was the active one, offer the open
-- picker to choose the next (Esc stays in no-workspace mode); if none are
-- left, stay in no-workspace mode.
local function delete_confirmed(name)
	local ok, was_active = session.delete(name)
	if not (ok and was_active) then
		return
	end
	if #storage.list() > 0 then
		vim.schedule(require("workspaces.ui.workspace_picker").open)
	else
		util.notify("No workspaces left (no-workspace mode).")
	end
end

-- Confirm + delete. opts.popup: Telescope confirm popup (pickers); otherwise
-- the command-line y/N prompt (:WorkspaceDelete <name>).
function M.delete(name, opts)
	opts = opts or {}
	if not storage.exists(name) then
		util.notify("No such workspace: " .. name, vim.log.levels.WARN)
		return
	end
	if opts.popup then
		require("workspaces.ui.confirm").ask("Delete workspace '" .. name .. "'?", function()
			delete_confirmed(name)
		end)
	elseif session.confirm_delete(name) then
		delete_confirmed(name)
	end
end

function M.open()
	local names = storage.list()
	if #names == 0 then
		util.notify("No saved workspaces.")
		return
	end
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values

	require("telescope.pickers")
		.new({}, {
			prompt_title = "Delete Workspace",
			results_title = "<CR> delete",
			finder = require("telescope.finders").new_table({ results = names }),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection then
						vim.schedule(function()
							M.delete(selection.value or selection[1], { popup = true })
						end)
					end
				end)
				return true
			end,
		})
		:find()
end

return M
