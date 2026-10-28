-- Telescope picker for switching to (or creating / deleting) a workspace.
local storage = require("workspaces.storage")
local session = require("workspaces.session")

local M = {}

local NEW_ENTRY = "[New Workspace]"
local LEGEND = "<CR> open · <C-d> delete"

local function results()
	local list = { NEW_ENTRY }
	vim.list_extend(list, storage.list())
	return list
end

local function finder()
	return require("telescope.finders").new_table({ results = results() })
end

local function ago(t)
	local d = os.time() - t
	if d < 60 then
		return "just now"
	elseif d < 3600 then
		return math.floor(d / 60) .. "m ago"
	elseif d < 86400 then
		return math.floor(d / 3600) .. "h ago"
	end
	return math.floor(d / 86400) .. "d ago"
end

-- Preview: last saved time + folder labels, missing folders flagged.
local function previewer()
	local util = require("workspaces.util")
	return require("telescope.previewers").new_buffer_previewer({
		title = "Workspace",
		define_preview = function(self, entry)
			local name = entry.value or entry[1]
			local lines
			if name == NEW_ENTRY then
				lines = { "Create a new, empty workspace." }
			else
				local t = vim.fn.getftime(storage.session_file(name))
				local folders = storage.read_folders(name)
				lines = {
					"Last saved: " .. (t > 0 and (os.date("%Y-%m-%d %H:%M", t) .. " (" .. ago(t) .. ")") or "unknown"),
					"",
					"Folders (" .. #folders .. "):",
				}
				for _, f in ipairs(folders) do
					local missing = vim.fn.isdirectory(f) == 0
					table.insert(lines, "  " .. util.folder_label(f) .. (missing and "   [missing]" or ""))
				end
				if #folders == 0 then
					table.insert(lines, "  (none)")
				end
			end
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
		end,
	})
end

function M.open()
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values

	require("telescope.pickers")
		.new({}, {
			prompt_title = "Select Workspace Session",
			results_title = LEGEND,
			finder = finder(),
			sorter = conf.generic_sorter({}),
			previewer = previewer(),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if not selection then
						return
					end
					local choice = selection.value or selection[1]
					vim.schedule(function()
						if choice == NEW_ENTRY then
							session.new()
						else
							session.switch(choice)
						end
					end)
				end)

				-- Delete the highlighted workspace after a confirm popup. Telescope
				-- shows one picker at a time, so this picker closes for the popup
				-- and reopens afterwards (refreshed), whatever the answer.
				local function delete()
					local selection = action_state.get_selected_entry()
					local name = selection and (selection.value or selection[1])
					if not name or name == NEW_ENTRY then
						return
					end
					actions.close(prompt_bufnr)
					vim.schedule(function()
						require("workspaces.ui.confirm").ask("Delete workspace '" .. name .. "'?", function()
							session.delete(name) -- active one -> no-workspace mode
							M.open()
						end, M.open)
					end)
				end
				map("i", "<C-d>", delete)
				map("n", "<C-d>", delete)
				return true
			end,
		})
		:find()
end

return M
