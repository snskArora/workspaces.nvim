-- grep_with_mods_nitpicky: pick one or more folders (workspace folders and
-- every subdirectory inside them), then run the supercharged grep on just
-- those.
--
-- Resource notes: the scan streams into Telescope (never blocks), is killed
-- when the picker closes or re-scans, and nothing scanned outlives the picker.
-- The only state kept between uses is the last confirmed path list and the
-- exclude toggle.
local config = require("workspaces.config")
local state = require("workspaces.state")
local util = require("workspaces.util")

local M = {}

-- Kept for the whole Neovim session (also across workspace switches).
local last_selection = {} -- paths confirmed last time; pre-marked on open
local include_excluded = nil -- nil = use config default until toggled

local function opts()
	return config.options.grep_with_mods_nitpicky
end

local function with_slash(p)
	return p:match("/$") and p or p .. "/"
end

local function to_set(list)
	local set = {}
	for _, v in ipairs(list) do
		set[v] = true
	end
	return set
end

-- Label a path relative to the deepest workspace folder containing it.
local function label_for(path, folders, prefixes)
	local best
	for _, f in ipairs(folders) do
		if vim.startswith(path, f) and (not best or #f > #best) then
			best = f
		end
	end
	if not best then
		return path
	end
	return prefixes[best] .. path:sub(#best + 1)
end

-- Unlimited depth unless configured. The result cap is enforced by the finder
-- itself (works for fd and find alike, and on fd versions without --max-results).
local function scan_command(folders, skip_excluded)
	local o = opts()
	local exclude = skip_excluded and config.options.folder_picker.exclude or {}
	local fd = util.fd_binary()
	if fd then
		return util.fd_dirs_command(fd, folders, exclude, o.max_depth, true)
	end
	return util.find_dirs_command(folders, exclude, o.max_depth)
end

-- Build a streaming finder. Entries in `premark` are marked on `multi`, the
-- same MultiSelect object the picker is given.
local function make_finder(folders, premark, multi)
	local skip = not include_excluded
	local prefixes = {}
	for _, f in ipairs(folders) do
		prefixes[f] = util.folder_label(f)
	end
	local seen = {} -- dedupe (overlapping workspace folders)
	local count = 0
	local cap = opts().max_results
	local finder

	local function make(path)
		path = with_slash(path)
		if seen[path] then
			return nil
		end
		seen[path] = true
		local text = label_for(path, folders, prefixes)
		local entry = { value = path, display = text, ordinal = text }
		if premark[path] then
			multi:add(entry)
		end
		return entry
	end

	-- fd never lists the search roots themselves, so seed them up front.
	local roots = {}
	for _, f in ipairs(folders) do
		local e = make(f)
		if e then
			e.index = #roots + 1
			table.insert(roots, e)
		end
	end

	finder = require("telescope.finders.async_oneshot_finder")({
		results = roots,
		entry_maker = function(line)
			if line == "" then
				return nil
			end
			if type(cap) == "number" and count >= cap then
				if finder then
					finder.close() -- stop the scan, we have enough
				end
				return nil
			end
			local e = make(line)
			if e then
				count = count + 1
			end
			return e
		end,
		fn_command = function()
			local cmd = scan_command(folders, skip)
			return { command = table.remove(cmd, 1), args = cmd }
		end,
	})
	return finder
end

function M.open()
	local folders = state.folders
	if #folders == 0 then
		util.notify("Workspace has no folders.", vim.log.levels.WARN)
		return
	end
	if include_excluded == nil then
		include_excluded = opts().include_excluded and true or false
	end
	local toggle_key = type(opts().toggle_key) == "string" and opts().toggle_key or nil

	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values
	local MultiSelect = require("telescope.pickers.multi")
	local multi = MultiSelect:new()

	require("telescope.pickers")
		.new({}, {
			_multi = multi,
			prompt_title = "Folders to grep",
			results_title = "<Tab> mark · <CR> grep" .. (toggle_key and (" · " .. toggle_key .. " excluded dirs") or ""),
			finder = make_finder(folders, to_set(last_selection), multi),
			sorter = conf.generic_sorter({}),
			previewer = false,
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local marked = action_state.get_current_picker(prompt_bufnr):get_multi_selection()
					if #marked == 0 then
						util.notify("Select at least one folder (<Tab> to mark).", vim.log.levels.WARN)
						return
					end
					local dirs = {}
					for _, e in ipairs(marked) do
						table.insert(dirs, e.value)
					end
					last_selection = dirs
					actions.close(prompt_bufnr)
					require("workspaces.integrations.multigrep").open({ search_dirs = dirs })
				end)

				local function toggle_excluded()
					local current = action_state.get_current_picker(prompt_bufnr)
					local keep = {}
					for _, e in ipairs(current:get_multi_selection()) do
						table.insert(keep, e.value)
					end
					include_excluded = not include_excluded
					util.notify(include_excluded and "Including excluded folders" or "Skipping excluded folders")
					local fresh = MultiSelect:new()
					current:refresh(make_finder(folders, to_set(keep), fresh), {
						reset_prompt = false,
						multi = fresh,
					})
				end
				if toggle_key then
					map("i", toggle_key, toggle_excluded)
					map("n", toggle_key, toggle_excluded)
				end
				return true
			end,
		})
		:find()
end

return M
