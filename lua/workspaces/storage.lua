-- On-disk layout: <session_dir>/<name>.vim (mksession output, executed by
-- :source when the workspace opens) and <name>.json (the folder list, data
-- only). Folder files from older versions (<name>.vars.lua) are converted to
-- JSON the first time they're read, without executing them.
local config = require("workspaces.config")
local util = require("workspaces.util")

local M = {}

local MAX_FOLDER_FILE = 1024 * 1024 -- anything bigger is not a folder list

local ensured -- session_dir already created (or attempted) this session

-- Session dir, created 0700 on first use: session files can contain private
-- paths and are executed when sourced.
local function dir()
	local d = config.options.session_dir
	if ensured ~= d then
		ensured = d
		local ok, err = pcall(vim.fn.mkdir, d, "p", tonumber("700", 8))
		if not ok or vim.fn.isdirectory(d) == 0 then
			util.notify("Cannot create session dir " .. d .. ": " .. tostring(err), vim.log.levels.ERROR)
		end
	end
	return d
end

-- A workspace name is a plain file name: no path separators, not hidden, no
-- control characters. Returns ok, error message.
function M.valid_name(name)
	if type(name) ~= "string" or name == "" or #name > 200 then
		return false, "Workspace name must be 1-200 characters."
	end
	if name:find("[/\\%c]") then
		return false, "Workspace name can't contain '/', '\\' or control characters."
	end
	if name:sub(1, 1) == "." then
		return false, "Workspace name can't start with '.'."
	end
	return true
end

function M.session_file(name)
	return dir() .. name .. ".vim"
end

function M.folders_file(name)
	return dir() .. name .. ".json"
end

local function legacy_folders_file(name)
	return dir() .. name .. ".vars.lua"
end

-- Names of all saved workspaces, sorted.
function M.list()
	local d = dir()
	local names = {}
	if vim.fn.isdirectory(d) == 1 then
		local files = vim.fn.readdir(d, function(n)
			return (#n > 4 and n:sub(1, 1) ~= "." and n:sub(-4) == ".vim") and 1 or 0
		end)
		for _, f in ipairs(files) do
			table.insert(names, f:sub(1, -5))
		end
	end
	table.sort(names)
	return names
end

function M.exists(name)
	return M.valid_name(name) and vim.fn.filereadable(M.session_file(name)) == 1
end

-- Remove every file of a workspace. Returns true if the session file is gone.
function M.delete(name)
	if not M.valid_name(name) then
		return false
	end
	os.remove(M.session_file(name))
	os.remove(M.folders_file(name))
	os.remove(legacy_folders_file(name))
	return vim.fn.filereadable(M.session_file(name)) == 0
end

local function read_file(path, limit)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read(limit or "*a")
	f:close()
	return s
end

-- Keep only non-empty strings, each ending in "/".
local function sanitize(list)
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for _, v in ipairs(list) do
		if type(v) == "string" and v ~= "" then
			table.insert(out, v:match("/$") and v or v .. "/")
		end
	end
	return out
end

-- Returns true on success; `quiet` skips the error message.
function M.write_folders(name, folders, quiet)
	local path = M.folders_file(name)
	local f, err = io.open(path, "w")
	if not f then
		if not quiet then
			util.notify("Cannot write " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
		end
		return false
	end
	f:write(#folders == 0 and "[]" or vim.json.encode(folders))
	f:close()
	return true
end

-- Old `return { "...", "..." }` files: evaluated as a chunk with no globals
-- (data only), then rewritten as JSON. Returns nil if there is no such file.
local function read_legacy(name)
	local path = legacy_folders_file(name)
	local src = read_file(path, MAX_FOLDER_FILE)
	if not src then
		return nil
	end
	local folders = {}
	local chunk = load(src, "=workspace-folders", "t", {})
	if chunk then
		local ok, data = pcall(chunk)
		if ok then
			folders = sanitize(data)
		end
	end
	if M.write_folders(name, folders, true) then
		os.remove(path)
	end
	return folders
end

function M.read_folders(name)
	local src = read_file(M.folders_file(name), MAX_FOLDER_FILE)
	if src then
		local ok, data = pcall(vim.json.decode, src)
		return ok and sanitize(data) or {}
	end
	return read_legacy(name) or {}
end

return M
