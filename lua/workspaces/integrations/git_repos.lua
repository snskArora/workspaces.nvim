-- Git repositories of the workspace: discovery, async status, and the shared
-- Telescope repo picker used by every "which repository?" prompt.
local state = require("workspaces.state")
local util = require("workspaces.util")

local M = {}

local function with_slash(p)
	return p:match("/$") and p or p .. "/"
end

-- Git root (with trailing "/") of a file or directory, or nil. Pure Lua
-- (stat calls via vim.fs.root), no git process.
function M.root_of(path)
	local root = vim.fs.root(path, ".git")
	return root and with_slash(root) or nil
end

-- Unique git roots of the workspace folders. Non-git folders are skipped and
-- folders inside the same repo collapse into one entry.
function M.roots()
	local seen, roots = {}, {}
	for _, folder in ipairs(state.folders) do
		local root = M.root_of(folder)
		if root and not seen[root] then
			seen[root] = true
			table.insert(roots, root)
		end
	end
	return roots
end

-- Async `git status` summary: cb({ branch = "main", changed = 3 }) on the
-- main loop. Tracked changes only. Returns the vim.system handle.
function M.status(root, cb)
	return vim.system(
		{ "git", "-C", root, "status", "--porcelain=v1", "-b", "--untracked-files=no" },
		{ text = true },
		function(res)
			local info = { branch = "?", changed = 0 }
			if res.code == 0 then
				local lines = vim.split(res.stdout or "", "\n", { trimempty = true })
				local head = (lines[1] or ""):sub(4):gsub("^No commits yet on ", "")
				info.branch = head:match("^(.-)%.%.%.") or head:match("^(%S+)") or "?"
				info.changed = math.max(#lines - 1, 0)
			end
			vim.schedule(function()
				cb(info)
			end)
		end
	)
end

-- Kill any still-running jobs when a picker's prompt buffer goes away.
function M.kill_on_close(bufnr, jobs)
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = bufnr,
		once = true,
		callback = function()
			for _, job in ipairs(jobs) do
				pcall(function()
					job:kill(15)
				end)
			end
		end,
	})
end

-- Ask which repository to use.
--   0 workspace folders -> cb(nil) (caller falls back to cwd)
--   0 git repos         -> warn, nothing
--   1 repo              -> cb(root) directly, unless opts.always
--   otherwise           -> Telescope picker: "work/app/ (main, 3 changed)"
function M.pick(prompt, cb, opts)
	opts = opts or {}
	if #state.folders == 0 then
		return cb(nil)
	end
	local roots = M.roots()
	if #roots == 0 then
		util.notify("No git repositories in this workspace.", vim.log.levels.WARN)
		return
	end
	if #roots == 1 and not opts.always then
		return cb(roots[1])
	end

	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values
	local info = {} -- root -> { branch, changed }; filled asynchronously

	local picker = require("telescope.pickers").new({}, {
		prompt_title = prompt or "Select repository",
		results_title = "<CR> select",
		finder = require("telescope.finders").new_table({
			results = roots,
			entry_maker = function(root)
				local label = util.folder_label(root)
				return {
					value = root,
					ordinal = label,
					display = function()
						local i = info[root]
						if not i then
							return label .. " (…)"
						end
						return string.format("%s (%s, %d changed)", label, i.branch, i.changed)
					end,
				}
			end,
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if selection then
					-- next tick: lets this picker finish closing before cb opens another
					vim.schedule(function()
						cb(selection.value)
					end)
				end
			end)
			return true
		end,
	})
	picker:find()

	-- Fill in branch / changed counts; one redraw once all repos answered.
	local pending, jobs = #roots, {}
	for _, root in ipairs(roots) do
		table.insert(
			jobs,
			M.status(root, function(i)
				info[root] = i
				pending = pending - 1
				if pending == 0 and picker.prompt_bufnr and vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
					picker:refresh(nil, { reset_prompt = false })
				end
			end)
		)
	end
	M.kill_on_close(picker.prompt_bufnr, jobs)
end

return M
