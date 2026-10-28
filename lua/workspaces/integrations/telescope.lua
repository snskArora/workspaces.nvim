-- Multi-root aware Telescope searches. With no workspace folders they fall
-- back to the regular cwd-based builtins.
local state = require("workspaces.state")

local M = {}

local function builtin()
	return require("telescope.builtin")
end

local function dirs_opts()
	if #state.folders == 0 then
		return {}
	end
	return { search_dirs = state.folders }
end

function M.find_files()
	builtin().find_files(dirs_opts())
end

function M.live_grep()
	builtin().live_grep(dirs_opts())
end

function M.grep_string()
	builtin().grep_string(dirs_opts())
end

function M.grep_with_mods()
	require("workspaces.integrations.multigrep").open(dirs_opts())
end

local function in_workspace(file)
	for _, folder in ipairs(state.folders) do
		if vim.startswith(file, folder) then
			return true
		end
	end
	return false
end

-- :oldfiles filtered to files inside any workspace folder. The cheap prefix
-- test runs first so only candidates are stat'ed.
function M.oldfiles()
	if #state.folders == 0 then
		builtin().oldfiles()
		return
	end
	local results = {}
	for _, file in ipairs(vim.v.oldfiles) do
		if in_workspace(file) and vim.fn.filereadable(file) == 1 then
			table.insert(results, file)
		end
	end
	local conf = require("telescope.config").values
	require("telescope.pickers")
		.new({}, {
			prompt_title = "Recent Files (workspace)",
			finder = require("telescope.finders").new_table({
				results = results,
				entry_maker = require("telescope.make_entry").gen_from_file({}),
			}),
			sorter = conf.file_sorter({}),
			previewer = conf.file_previewer({}),
		})
		:find()
end

return M
