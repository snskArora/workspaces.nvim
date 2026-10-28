-- "Supercharged" ripgrep picker: a pattern plus optional globs, re-run on
-- every keystroke, across the given search_dirs (or cwd).
--
-- Prompt syntax:  <pattern> |:| <glob>, <glob>
--   e.g.  TODO |:| *.lua, !**/tests/**
local util = require("workspaces.util")

local M = {}

local SEPARATOR = " |:| "

local function build_args(prompt, search_dirs)
	if not prompt or vim.trim(prompt) == "" then
		return nil
	end
	local parts = vim.split(prompt, SEPARATOR, { plain = true })
	if parts[1] == "" then
		return nil -- globs alone would match every line of every file
	end
	local args = { "rg", "-e", parts[1] }
	if parts[2] then
		for _, glob in ipairs(vim.split(parts[2], ", ", { plain = true })) do
			if glob ~= "" then
				table.insert(args, "-g")
				table.insert(args, glob)
			end
		end
	end
	vim.list_extend(args, { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" })
	if search_dirs and #search_dirs > 0 then
		table.insert(args, "--")
		vim.list_extend(args, search_dirs)
	end
	return args
end

function M.open(opts)
	if not util.has_rg() then
		util.notify("ripgrep (rg) is not installed.", vim.log.levels.ERROR)
		return
	end
	opts = opts or {}
	opts.cwd = opts.cwd or vim.fn.getcwd(-1, -1)
	local conf = require("telescope.config").values
	local finder = require("telescope.finders").new_async_job({
		command_generator = function(prompt)
			return build_args(prompt, opts.search_dirs)
		end,
		entry_maker = require("telescope.make_entry").gen_from_vimgrep(opts),
		cwd = opts.cwd,
	})
	require("telescope.pickers")
		.new(opts, {
			debounce = 100,
			prompt_title = "Supercharged Multi Grep",
			finder = finder,
			previewer = conf.grep_previewer(opts),
			sorter = require("telescope.sorters").empty(),
		})
		:find()
end

return M
