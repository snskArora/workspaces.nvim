-- One-line name popup, styled like a Telescope prompt (Telescope's highlight
-- groups, rounded border, title on top, keys in the bottom border).
-- A real Telescope picker always needs a results window, so this is a plain
-- floating prompt buffer. <CR> submits, Esc / <C-c> / leaving the window cancels.
local util = require("workspaces.util")

local M = {}

-- opts: title, legend, validate(name) -> error string | nil, on_submit(name)
function M.ask(opts)
	local width = math.max(36, vim.fn.strdisplaywidth(opts.title) + 10, vim.fn.strdisplaywidth(opts.legend) + 6)
	width = math.max(10, math.min(width, vim.o.columns - 4))
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "prompt"
	vim.bo[buf].bufhidden = "wipe"
	vim.fn.prompt_setprompt(buf, "> ")

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - 3) / 2)),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		width = width,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = " " .. opts.title .. " ",
		title_pos = "center",
		footer = " " .. opts.legend .. " ",
		footer_pos = "center",
	})
	vim.wo[win].winhighlight =
		"Normal:TelescopePromptNormal,FloatBorder:TelescopePromptBorder,FloatTitle:TelescopePromptTitle,FloatFooter:TelescopePromptBorder"

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		vim.cmd("stopinsert")
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	vim.fn.prompt_setcallback(buf, function(text)
		local name = vim.trim(text or "")
		local err = name == "" and "Type a name (Esc to cancel)." or (opts.validate and opts.validate(name))
		if err then
			util.notify(err, vim.log.levels.WARN)
			-- prompt buffers append a new prompt line after each <CR>: reset to one
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(buf) then
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
					vim.cmd("startinsert!")
				end
			end)
			return
		end
		close()
		vim.schedule(function()
			opts.on_submit(name)
		end)
	end)

	for _, mode in ipairs({ "i", "n" }) do
		vim.keymap.set(mode, "<Esc>", close, { buffer = buf, nowait = true })
		vim.keymap.set(mode, "<C-c>", close, { buffer = buf, nowait = true })
	end
	vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = close })
	vim.cmd("startinsert!")
end

return M
