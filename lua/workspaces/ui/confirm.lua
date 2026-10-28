-- Small Telescope dropdown asking a yes/no question. "No" is listed first, so
-- it's highlighted by default. <CR> picks the highlighted entry; closing the
-- popup any other way (Esc, <C-c>) counts as "no".
local M = {}

-- on_yes / on_no run on the next tick, after the popup has closed.
function M.ask(title, on_yes, on_no)
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values
	local decided = false

	local opts = require("telescope.themes").get_dropdown({
		previewer = false,
		layout_config = {
			width = math.min(math.max(44, vim.fn.strdisplaywidth(title) + 8), math.max(20, vim.o.columns - 4)),
			height = math.min(8, math.max(4, vim.o.lines - 4)),
		},
	})
	opts.results_title = "<CR> choose · Esc keep" -- the dropdown theme turns this off

	local picker = require("telescope.pickers").new(opts, {
		prompt_title = title,
		finder = require("telescope.finders").new_table({
			results = { { "No, keep it", false }, { "Yes, delete", true } },
			entry_maker = function(e)
				return { value = e[2], display = e[1], ordinal = e[1] }
			end,
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				decided = true
				actions.close(prompt_bufnr)
				local yes = selection and selection.value
				vim.schedule(function()
					if yes then
						on_yes()
					elseif on_no then
						on_no()
					end
				end)
			end)
			return true
		end,
	})
	picker:find()

	-- Closed without <CR> (Esc / <C-c>) -> treat as "no".
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = picker.prompt_bufnr,
		once = true,
		callback = function()
			if not decided and on_no then
				vim.schedule(on_no)
			end
		end,
	})
end

return M
