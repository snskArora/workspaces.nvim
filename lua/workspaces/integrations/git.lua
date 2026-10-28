-- Neogit and git-worktree.nvim integration (both optional, each with its own
-- `integrations.<name>` switch).
local config = require("workspaces.config")
local state = require("workspaces.state")
local util = require("workspaces.util")
local repos = require("workspaces.integrations.git_repos")

local M = {}

local function optional(module, label)
	local ok, mod = pcall(require, module)
	if not ok then
		util.notify(label .. " is not installed.", vim.log.levels.WARN)
		return nil
	end
	return mod
end

-- false (with a warning) when the user switched the integration off.
local function enabled(name, label)
	if config.integration(name) then
		return true
	end
	util.notify(label .. " integration is disabled (integrations." .. name .. " = false).", vim.log.levels.WARN)
	return false
end

-- Neogit -------------------------------------------------------------------

-- Repo of the current buffer, but only for a real file (not a plugin/UI
-- buffer) that lives inside a workspace folder. Pure Lua, no git call.
local function buffer_repo()
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].buftype ~= "" then
		return nil
	end
	local file = vim.api.nvim_buf_get_name(buf)
	if file == "" then
		return nil
	end
	file = vim.fn.fnamemodify(file, ":p")
	for _, folder in ipairs(state.folders) do
		if vim.startswith(file, folder) then
			return vim.fn.filereadable(file) == 1 and repos.root_of(file) or nil
		end
	end
	return nil
end

function M.neogit()
	if not enabled("neogit", "Neogit") then
		return
	end
	local neogit = optional("neogit", "Neogit")
	if not neogit then
		return
	end
	local root = buffer_repo()
	if root then
		return neogit.open({ cwd = root })
	end
	repos.pick("Open Neogit for repository", function(path)
		neogit.open(path and { cwd = path } or {})
	end, { always = true })
end

-- git-worktree --------------------------------------------------------------
-- Outside a workspace: git-worktree.nvim behaves exactly as upstream.
-- In a workspace: nothing changes the cwd. Creating a worktree adds it as a
-- workspace folder, picking one in the list adds it, deleting one removes it.

-- { kind = "create" | "list", repo = "/abs/repo/" }: set when one of our
-- worktree pickers opens, used up by the first git-worktree call it applies
-- to, reset whenever a worktree key is pressed, and only honoured while a
-- workspace is active. (Not tied to the picker buffer: Telescope's close
-- action runs scheduled callbacks before git-worktree is called.)
local ctx = nil
local add_instead_of_switch = {} -- worktree path -> absolute path (after our create)
local patched = false

local function reset()
	ctx = nil
	add_instead_of_switch = {}
end

local function noau_cd(dir)
	vim.cmd("noautocmd cd " .. vim.fn.fnameescape(dir))
end

-- Take ctx if it matches `kind` (and we're in a workspace); it's used once.
local function take(kind)
	if ctx and ctx.kind == kind and state.active then
		local c = ctx
		ctx = nil
		return c
	end
	return nil
end

-- Drop a removed worktree, and any workspace folder inside it.
local function forget_folder(path)
	local dir = path:match("/$") and path or path .. "/"
	local gone = {}
	for _, f in ipairs(state.folders) do
		if f == dir or vim.startswith(f, dir) then
			table.insert(gone, f)
		end
	end
	if #gone > 0 then
		require("workspaces.folders").remove_many(gone)
	end
end

local function patch(gw)
	if patched then
		return
	end
	patched = true
	local orig_create, orig_switch, orig_delete = gw.create_worktree, gw.switch_worktree, gw.delete_worktree

	-- git-worktree resolves the repo from the cwd synchronously at the start
	-- (its jobs then carry explicit cwds), so a momentary cd is enough.
	gw.create_worktree = function(path, branch, upstream)
		local c = take("create")
		if not c then
			return orig_create(path, branch, upstream)
		end
		local repo, cwd = c.repo, vim.fn.getcwd(-1, -1)
		noau_cd(repo)
		local ok, err = pcall(function()
			orig_create(path, branch, upstream)
			add_instead_of_switch[path] = gw.get_worktree_path(path)
		end)
		noau_cd(cwd)
		if not ok then
			error(err)
		end
	end

	-- After create, git-worktree switches into the new tree: add it instead.
	-- From our list picker, "switch" means "add to workspace".
	gw.switch_worktree = function(path)
		local abs = add_instead_of_switch[path]
		if abs and state.active then
			add_instead_of_switch[path] = nil
			return require("workspaces.folders").add(abs)
		end
		if take("list") then
			return require("workspaces.folders").add(path)
		end
		return orig_switch(path)
	end

	-- Delete from our list picker: run `git worktree remove` against the repo
	-- directly (no cwd change), then drop it from the workspace if present.
	gw.delete_worktree = function(path, force, opts)
		local c = take("list")
		if not c then
			return orig_delete(path, force, opts)
		end
		opts = opts or {}
		local cmd = { "git", "-C", c.repo, "worktree", "remove" }
		if force then
			table.insert(cmd, "--force")
		end
		vim.list_extend(cmd, { "--", path })
		vim.system(cmd, { text = true }, function(res)
			vim.schedule(function()
				if res.code == 0 then
					util.notify("Deleted worktree: " .. path)
					forget_folder(path)
					if opts.on_success then
						opts.on_success()
					end
				else
					util.notify("Deleting worktree failed: " .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
					if opts.on_failure then
						opts.on_failure(res)
					end
				end
			end)
		end)
	end
end

-- Repo for worktree actions in a workspace: picked, or the cwd's repo when
-- the workspace has no folders yet.
local function with_workspace_repo(fn)
	repos.pick("Select repository", function(root)
		root = root or repos.root_of(vim.fn.getcwd(-1, -1))
		if not root then
			util.notify("Not in a git repository.", vim.log.levels.WARN)
			return
		end
		fn(root)
	end)
end

-- git-worktree module + its Telescope extension, or nil (with a warning).
local function worktree()
	local gw = optional("git-worktree", "git-worktree.nvim")
	if not gw then
		return nil
	end
	local ok, telescope = pcall(require, "telescope")
	local ext = ok and telescope.extensions and telescope.extensions.git_worktree
	if not ext then
		util.notify("Telescope extension git_worktree is not loaded.", vim.log.levels.WARN)
		return nil
	end
	return gw, ext
end

function M.worktrees()
	if not enabled("git_worktree", "git-worktree") then
		return
	end
	reset()
	local gw, ext = worktree()
	if not gw then
		return
	end
	if not state.active then
		return ext.git_worktrees({})
	end
	patch(gw)
	with_workspace_repo(function(repo)
		local cwd = vim.fn.getcwd(-1, -1)
		ctx = { kind = "list", repo = repo }
		noau_cd(repo) -- the list picker runs `git worktree list` in the cwd, synchronously
		local ok, err = pcall(ext.git_worktrees, {})
		noau_cd(cwd)
		if not ok then
			ctx = nil
			util.notify("git-worktree failed: " .. tostring(err), vim.log.levels.ERROR)
		end
	end)
end

function M.create_worktree()
	if not enabled("git_worktree", "git-worktree") then
		return
	end
	reset()
	local gw, ext = worktree()
	if not gw then
		return
	end
	if not state.active then
		return ext.create_git_worktree({})
	end
	patch(gw)
	with_workspace_repo(function(repo)
		ctx = { kind = "create", repo = repo }
		ext.create_git_worktree({ cwd = repo }) -- branch picker of that repo, no cd
	end)
end

return M
