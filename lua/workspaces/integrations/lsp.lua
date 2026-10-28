-- Register workspace folders with LSP servers (workspace/didChangeWorkspaceFolders)
-- so workspace symbols / references span every folder.
--
-- Only folders this plugin added are ever removed again; a server's own root
-- folder is left alone. Servers must advertise workspaceFolders support.
local config = require("workspaces.config")
local state = require("workspaces.state")

local M = {}

local added = {} -- client id -> { [dir] = true } folders we registered

-- Neovim 0.11 made client methods `client:notify(...)`; 0.10 only has the
-- closure form `client.notify(...)`.
local notify = vim.fn.has("nvim-0.11") == 1
		and function(client, method, params)
			return client:notify(method, params)
		end
	or function(client, method, params)
		return client.notify(method, params)
	end

local function allowed(client)
	local opts = config.options.lsp
	if type(opts) ~= "table" or opts.enabled == false then
		return false
	end
	if type(opts.servers) == "table" and not vim.tbl_contains(opts.servers, client.name) then
		return false
	end
	local ws = client.server_capabilities and client.server_capabilities.workspace
	return (ws and ws.workspaceFolders and ws.workspaceFolders.supported) and true or false
end

local function folder(dir)
	return { uri = vim.uri_from_fname(dir), name = dir }
end

function M.sync_client(client)
	if not allowed(client) then
		return
	end
	local mine = added[client.id] or {}
	added[client.id] = mine

	local want = {}
	for _, f in ipairs(state.folders) do
		want[(f:gsub("/$", ""))] = true
	end
	local have = {}
	for _, wf in ipairs(client.workspace_folders or {}) do
		have[wf.name] = true
	end

	local add, remove = {}, {}
	for dir in pairs(want) do
		if not have[dir] then
			table.insert(add, folder(dir))
			mine[dir] = true
		end
	end
	for dir in pairs(mine) do
		if not want[dir] then
			table.insert(remove, folder(dir))
			mine[dir] = nil
		end
	end
	if #add == 0 and #remove == 0 then
		return
	end

	local ok = pcall(notify, client, "workspace/didChangeWorkspaceFolders", { event = { added = add, removed = remove } })
	if not ok then
		return
	end
	local gone = {}
	for _, wf in ipairs(remove) do
		gone[wf.name] = true
	end
	local list = {}
	for _, wf in ipairs(client.workspace_folders or {}) do
		if not gone[wf.name] then
			table.insert(list, wf)
		end
	end
	vim.list_extend(list, add)
	client.workspace_folders = list
end

-- Re-sync every running client (after add/remove/switch/delete).
function M.sync()
	local opts = config.options.lsp
	if type(opts) ~= "table" or opts.enabled == false then
		return
	end
	for _, client in ipairs(vim.lsp.get_clients()) do
		M.sync_client(client)
	end
end

function M.setup(group)
	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client then
				M.sync_client(client)
			end
		end,
	})
	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(args)
			-- forget bookkeeping only when the client is gone entirely
			vim.schedule(function()
				if not vim.lsp.get_client_by_id(args.data.client_id) then
					added[args.data.client_id] = nil
				end
			end)
		end,
	})
end

return M
