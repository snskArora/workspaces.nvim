local M = {}

function M.notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "workspaces" })
end

-- Resolve a raw/typed path ("~", $VARS, relative) to an absolute directory
-- path ending in "/". Returns nil if it isn't a directory. vim.fs.normalize
-- (not vim.fn.expand) so "%" and "#" in a path aren't turned into buffer names.
function M.normalize_dir(raw)
	if type(raw) ~= "string" then
		return nil
	end
	raw = vim.trim(raw)
	if raw == "" then
		return nil
	end
	local dir = vim.fn.fnamemodify(vim.fs.normalize(raw), ":p")
	if vim.fn.isdirectory(dir) == 0 then
		return nil
	end
	return dir:match("/$") and dir or dir .. "/"
end

-- `:cd` to the common root of the workspace folders (even "/" when they
-- share nothing). With 0 folders the cwd is left alone. Set
-- `cwd_follows_root = false` to disable.
function M.follow_root(folders)
	if not require("workspaces.config").options.cwd_follows_root or #folders == 0 then
		return
	end
	local root = M.common_ancestor(folders)
	local current = vim.fn.getcwd(-1, -1)
	if not root or (current:match("/$") and current or current .. "/") == root then
		return
	end
	local ok, err = pcall(vim.cmd, "cd " .. vim.fn.fnameescape(root))
	if not ok then
		M.notify("Could not cd to workspace root " .. root .. ": " .. tostring(err), vim.log.levels.WARN)
	end
end

-- "<parent>/<folder>/" label, e.g. /home/me/work/app/ -> work/app/
function M.folder_label(folder)
	local trimmed = folder:gsub("/$", "")
	if trimmed == "" then
		return "/"
	end
	local name = vim.fn.fnamemodify(trimmed, ":t")
	local parent = vim.fn.fnamemodify(trimmed, ":h:t")
	if parent == "" or parent == "/" or parent == "." then
		return name .. "/"
	end
	return parent .. "/" .. name .. "/"
end

-- Deepest directory shared by all paths. nvim-tree can only show one root,
-- so we anchor it here to keep every workspace folder reachable.
function M.common_ancestor(paths)
	if #paths == 0 then
		return nil
	end
	if #paths == 1 then
		return paths[1]
	end
	local function segments(p)
		local segs = {}
		for seg in p:gmatch("[^/]+") do
			table.insert(segs, seg)
		end
		return segs
	end
	local common_segs = segments(paths[1])
	local common_len = #common_segs
	for i = 2, #paths do
		local segs = segments(paths[i])
		local j = 0
		local max_check = math.min(common_len, #segs)
		while j < max_check and common_segs[j + 1] == segs[j + 1] do
			j = j + 1
		end
		common_len = j
		if common_len == 0 then
			break
		end
	end
	if common_len == 0 then
		return "/"
	end
	return "/" .. table.concat(common_segs, "/", 1, common_len) .. "/"
end

local fd -- cached: false = none found
-- "fd" or "fdfind" if installed, else nil. One PATH scan per session.
function M.fd_binary()
	if fd == nil then
		fd = (vim.fn.executable("fd") == 1 and "fd") or (vim.fn.executable("fdfind") == 1 and "fdfind") or false
	end
	return fd or nil
end

local rg -- cached
function M.has_rg()
	if rg == nil then
		rg = vim.fn.executable("rg") == 1
	end
	return rg
end

-- `find <bases...> -mindepth 1 [-maxdepth N] ( -name X ... ) -prune -o -type d -print`
function M.find_dirs_command(bases, exclude, max_depth, min_depth)
	local cmd = { "find" }
	vim.list_extend(cmd, bases)
	vim.list_extend(cmd, { "-mindepth", tostring(min_depth or 1) })
	if type(max_depth) == "number" then
		vim.list_extend(cmd, { "-maxdepth", tostring(max_depth) })
	end
	exclude = type(exclude) == "table" and exclude or {}
	if #exclude > 0 then
		table.insert(cmd, "(")
		for i, name in ipairs(exclude) do
			if i > 1 then
				table.insert(cmd, "-o")
			end
			vim.list_extend(cmd, { "-name", name })
		end
		vim.list_extend(cmd, { ")", "-prune", "-o" })
	end
	vim.list_extend(cmd, { "-type", "d", "-print" })
	return cmd
end

-- `fd --type d --hidden [--no-ignore] [--max-depth N] --exclude X ... . <bases...>`
function M.fd_dirs_command(binary, bases, exclude, max_depth, no_ignore)
	local cmd = { binary, "--type", "d", "--hidden" }
	if no_ignore then
		table.insert(cmd, "--no-ignore")
	end
	if type(max_depth) == "number" then
		vim.list_extend(cmd, { "--max-depth", tostring(max_depth) })
	end
	for _, name in ipairs(type(exclude) == "table" and exclude or {}) do
		vim.list_extend(cmd, { "--exclude", name })
	end
	table.insert(cmd, ".")
	vim.list_extend(cmd, bases)
	return cmd
end

return M
