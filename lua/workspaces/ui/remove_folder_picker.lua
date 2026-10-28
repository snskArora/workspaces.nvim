-- Telescope picker for removing one or more folders (<leader>wd).
-- <Tab>/<CR> mark (and move down), <C-s> removes the marked folders, no
-- confirmation. Esc cancels; marks live only inside this picker.
local state = require("workspaces.state")
local util = require("workspaces.util")

local M = {}

function M.open()
	if #state.folders == 0 then
		util.notify("Workspace is empty.")
		return
	end
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values

	require("telescope.pickers")
		.new({}, {
			prompt_title = "Remove Folders from Workspace",
			results_title = "<Tab>/<CR> mark · <C-s> remove marked",
			finder = require("telescope.finders").new_table({
				results = state.folders,
				entry_maker = function(folder)
					local label = util.folder_label(folder)
					return { value = folder, display = label, ordinal = label }
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				local function mark()
					actions.toggle_selection(prompt_bufnr)
					actions.move_selection_worse(prompt_bufnr)
				end
				actions.select_default:replace(mark)

				local function apply()
					local marked = action_state.get_current_picker(prompt_bufnr):get_multi_selection()
					if #marked == 0 then
						util.notify("Mark at least one folder (<Tab>/<CR>).", vim.log.levels.WARN)
						return
					end
					local paths = {}
					for _, e in ipairs(marked) do
						table.insert(paths, e.value)
					end
					actions.close(prompt_bufnr)
					require("workspaces.folders").remove_many(paths)
				end
				for _, mode in ipairs({ "i", "n" }) do
					map(mode, "<Tab>", mark)
					map(mode, "<C-s>", apply)
				end
				return true
			end,
		})
		:find()
end

return M
