-- Telescope picker for choosing a directory to add to the workspace.
--
-- Normal mode: one scan of cwd (folder_picker.max_depth), <CR> adds.
-- Browse mode (<C-o>, remembered for the session): lists the current dir up
-- to folder_picker.browse_depth plus ../ and ../../; <Tab> hops in/out and
-- re-lists, <CR> adds the highlighted folder (on ../ and ../../ it hops up).
-- Always starts at the global cwd.
local config = require("workspaces.config")
local folders = require("workspaces.folders")
local util = require("workspaces.util")

local M = {}

local browse_mode = false -- remembered for the Neovim session

local LEGEND_NORMAL = "<CR> add · <C-y> typed path · <C-o> browse mode"
local LEGEND_BROWSE = "<Tab> open · <CR> add · <C-y> typed path · <C-o> normal mode"
local TITLE_NORMAL = "Select Folder to Add to Workspace"

local function with_slash(p)
	return p:match("/$") and p or p .. "/"
end

local function cwd()
	return with_slash(vim.fn.getcwd(-1, -1))
end

-- Normal mode scan: hidden dirs shown, exclude list skipped, .gitignore
-- respected (fd only).
local function scan_command(base)
	local opts = config.options.folder_picker
	local fd = util.fd_binary()
	if fd then
		return util.fd_dirs_command(fd, { base }, opts.exclude, opts.max_depth, false)
	end
	return util.find_dirs_command({ base }, opts.exclude, opts.max_depth)
end

-- Browse mode scan: like normal mode but gitignored dirs shown too.
local function browse_command(dir)
	local opts = config.options.folder_picker
	local fd = util.fd_binary()
	if fd then
		return util.fd_dirs_command(fd, { dir }, opts.exclude, opts.browse_depth, true)
	end
	return util.find_dirs_command({ dir }, opts.exclude, opts.browse_depth)
end

local function normal_finder()
	return require("telescope.finders").new_oneshot_job(scan_command(cwd()), {
		entry_maker = require("telescope.make_entry").gen_from_file({}),
	})
end

-- ../ and ../../ first (only when they lead somewhere new), then the listing.
local function browse_finder(dir)
	local function entry(path, text, is_up)
		return { value = path, display = text, ordinal = text, up = is_up }
	end
	local function parent_of(d)
		if d == "/" then
			return nil
		end
		return with_slash(vim.fn.fnamemodify(d:sub(1, -2), ":h"))
	end
	local up = {}
	local parent = parent_of(dir)
	if parent then
		table.insert(up, entry(parent, "../", true))
		local grandparent = parent_of(parent)
		if grandparent then
			table.insert(up, entry(grandparent, "../../", true))
		end
	end
	for i, e in ipairs(up) do
		e.index = i
	end
	local cmd = browse_command(dir)
	return require("telescope.finders.async_oneshot_finder")({
		results = up,
		entry_maker = function(line)
			if line == "" then
				return nil
			end
			local path = with_slash(line)
			if path == dir then
				return nil
			end
			return entry(path, path:sub(#dir + 1))
		end,
		fn_command = function()
			return { command = cmd[1], args = vim.list_slice(cmd, 2) }
		end,
	})
end

local function browse_title(dir)
	return "Browse: " .. vim.fn.fnamemodify(dir, ":~")
end

local function set_titles(picker, dir)
	pcall(function()
		local layout = picker.layout
		layout.results.border:change_title(browse_mode and LEGEND_BROWSE or LEGEND_NORMAL)
		layout.prompt.border:change_title(browse_mode and browse_title(dir) or TITLE_NORMAL)
	end)
end

function M.open()
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values
	local dir = cwd() -- browse location while this picker is open

	require("telescope.pickers")
		.new({}, {
			prompt_title = browse_mode and browse_title(dir) or TITLE_NORMAL,
			results_title = browse_mode and LEGEND_BROWSE or LEGEND_NORMAL,
			finder = browse_mode and browse_finder(dir) or normal_finder(),
			sorter = conf.file_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				local function picker()
					return action_state.get_current_picker(prompt_bufnr)
				end

				local function show(reset_prompt)
					local p = picker()
					p:refresh(browse_mode and browse_finder(dir) or normal_finder(), { reset_prompt = reset_prompt })
					set_titles(p, dir)
				end

				local function add_and_close(raw)
					actions.close(prompt_bufnr)
					folders.add(raw)
				end

				-- Browse: move into the highlighted folder (or up for ../).
				local function hop()
					local selection = action_state.get_selected_entry()
					if not selection then
						util.notify("Nothing to open.", vim.log.levels.WARN)
						return
					end
					dir = selection.value
					show(true)
				end

				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					if browse_mode then
						if not selection then
							util.notify("Nothing selected.", vim.log.levels.WARN)
						elseif selection.up then
							hop() -- ../ and ../../ always move up
						else
							add_and_close(selection.value)
						end
						return
					end
					-- No match (beyond max depth, excluded, other mount) -> use typed text
					add_and_close(selection and (selection.value or selection[1]) or action_state.get_current_line())
				end)

				local function tab()
					if browse_mode then
						hop()
					else
						-- keep Telescope's default <Tab> outside browse mode
						actions.toggle_selection(prompt_bufnr)
						actions.move_selection_worse(prompt_bufnr)
					end
				end

				local function use_typed()
					add_and_close(action_state.get_current_line())
				end

				local function toggle_browse()
					browse_mode = not browse_mode
					dir = cwd() -- browse always starts at cwd
					show(false)
				end

				for _, mode in ipairs({ "i", "n" }) do
					map(mode, "<Tab>", tab)
					map(mode, "<C-y>", use_typed)
					map(mode, "<C-o>", toggle_browse)
				end
				return true
			end,
		})
		:find()
end

return M
