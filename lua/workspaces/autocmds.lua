local M = {}

-- A "clean" interactive launch: a UI is attached, no file arguments, no
-- session (`nvim -S`), and nothing was read from stdin.
local function clean_launch()
	if #vim.api.nvim_list_uis() == 0 or vim.fn.argc() > 0 or vim.v.this_session ~= "" then
		return false
	end
	local buf = vim.api.nvim_get_current_buf()
	return vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

function M.setup(opts)
	local group = vim.api.nvim_create_augroup("WorkspacesNvim", { clear = true })

	if opts.startup_picker then
		vim.api.nvim_create_autocmd("VimEnter", {
			group = group,
			nested = true,
			callback = function()
				if clean_launch() then
					require("workspaces").open_workspace()
				end
			end,
		})
	end

	if opts.autosave and opts.autosave.on_exit then
		vim.api.nvim_create_autocmd("VimLeavePre", {
			group = group,
			callback = function()
				require("workspaces.session").save({ exiting = true })
			end,
		})
	end

	if opts.lsp and opts.lsp.enabled ~= false then
		require("workspaces.integrations.lsp").setup(group)
	end
end

return M
