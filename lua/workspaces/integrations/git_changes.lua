-- Changed files across every workspace repo (<leader>gs). Tracked changes
-- only; entries "XY work/app/src/x.lua"; preview = `git diff HEAD`.
local state = require("workspaces.state")
local util = require("workspaces.util")
local repos = require("workspaces.integrations.git_repos")

local M = {}

-- Parse `git status --porcelain=v1 -z` output into entries.
local function parse(root, stdout)
	local label = util.folder_label(root)
	local entries = {}
	local parts = vim.split(stdout or "", "\0", { plain = true })
	local i = 1
	while i <= #parts do
		local rec = parts[i]
		if #rec > 3 then
			local xy, rel = rec:sub(1, 2), rec:sub(4)
			local abs = root .. rel
			table.insert(entries, {
				value = abs,
				filename = abs,
				path = abs,
				root = root,
				rel = rel,
				ordinal = label .. rel,
				display = xy .. " " .. label .. rel,
			})
			if xy:find("[RC]") then
				i = i + 1 -- skip the original path of a rename/copy
			end
		end
		i = i + 1
	end
	return entries
end

-- One `git diff` at a time: moving the cursor quickly kills the previous one.
local function previewer()
	local job
	return require("telescope.previewers").new_buffer_previewer({
		title = "git diff HEAD",
		teardown = function()
			if job then
				pcall(job.kill, job, 15)
				job = nil
			end
		end,
		define_preview = function(self, entry)
			local bufnr = self.state.bufnr
			if job then
				pcall(job.kill, job, 15)
			end
			job = vim.system(
				{ "git", "-C", entry.root, "diff", "HEAD", "--", entry.rel },
				{ text = true },
				function(res)
					vim.schedule(function()
						if res.signal ~= 0 or not vim.api.nvim_buf_is_valid(bufnr) then
							return -- killed, or the preview buffer is gone
						end
						local text = res.code == 0 and res.stdout or (res.stderr or "")
						vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, "\n"))
						vim.bo[bufnr].filetype = "diff"
					end)
				end
			)
		end,
	})
end

function M.open()
	local roots = #state.folders > 0 and repos.roots() or { repos.root_of(vim.fn.getcwd(-1, -1)) }
	if #roots == 0 then
		util.notify("No git repositories in this workspace.", vim.log.levels.WARN)
		return
	end

	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local picker = require("telescope.pickers").new({}, {
		prompt_title = "Changed files (all workspace repos)",
		results_title = "<CR> open · loading…",
		finder = finders.new_table({ results = {} }),
		sorter = conf.generic_sorter({}),
		previewer = previewer(),
	})
	picker:find()

	local all, pending, jobs = {}, #roots, {}
	for _, root in ipairs(roots) do
		table.insert(
			jobs,
			vim.system(
				{ "git", "-C", root, "status", "--porcelain=v1", "-z", "--untracked-files=no" },
				{ text = true },
				function(res)
					vim.schedule(function()
						if res.code == 0 then
							vim.list_extend(all, parse(root, res.stdout))
						end
						pending = pending - 1
						if pending > 0 or not vim.api.nvim_buf_is_valid(picker.prompt_bufnr) then
							return
						end
						picker:refresh(
							finders.new_table({
								results = all,
								entry_maker = function(e)
									return e
								end,
							}),
							{ reset_prompt = false }
						)
						pcall(function()
							picker.layout.results.border:change_title(
								#all == 0 and "no changes" or ("<CR> open · " .. #all .. " changed")
							)
						end)
					end)
				end
			)
		)
	end
	repos.kill_on_close(picker.prompt_bufnr, jobs)
end

return M
