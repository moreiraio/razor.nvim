local util = require("lspconfig.util")

local function set_selected_target(bufnr, target)
	vim.g["RazorSelectedTarget" .. bufnr] = target
end

local function get_selected_target(bufnr)
	return vim.g["RazorSelectedTarget" .. bufnr]
end

---Finds the possible Targets
---@param fname string @The name of the file to find possible targets for
---@return string[], (string|nil) @The possible targets.
local function find_possible_targets(fname)
	local prefered_target = nil
	local targets = {}

	local sln_dir = util.root_pattern("*sln")(fname)
	if sln_dir then
		vim.list_extend(targets, vim.fn.glob(util.path.join(sln_dir, "*.sln"), true, true))
	end

	if #targets == 1 then
		prefered_target = targets[1]
	end

	-- local csproj_dir = util.root_pattern("*csproj")(fname)
	-- if csproj_dir then
	-- 	table.insert(targets, csproj_dir)
	-- end
	--
	-- local git_dir = util.root_pattern(".git")(fname)
	-- if git_dir and not vim.tbl_contains(targets, git_dir) then
	-- 	table.insert(targets, git_dir)
	-- end
	--
	-- local cwd = vim.fn.getcwd()
	-- if util.path.is_descendant(cwd, fname) and not vim.tbl_contains(targets, cwd) then
	-- 	table.insert(targets, cwd)
	-- end
	--
	-- if #targets == 1 then
	-- 	prefered_target = targets[1]
	-- end

	return targets, prefered_target
end

local M = {}

M.client_by_target = {} ---@type table<string, table|nil>
M.targets_by_bufnr = {} ---@type table<number, string[]>


function M.init_buf_targets(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_get_option(bufnr, "buftype") == "nofile" then
		return
	end

	if M.targets_by_bufnr[bufnr] ~= nil then
		return
	end

	local bufname = vim.api.nvim_buf_get_name(bufnr)
	if not util.bufname_valid(bufname) then
		return
	end
	print ("teste")
	local bufpath = util.path.sanitize(bufname)
	local targets, prefered_target = find_possible_targets(bufpath)
	if prefered_target then
		set_selected_target(bufnr, prefered_target)
	elseif #targets > 1 then
		vim.api.nvim_create_user_command("CSTarget", function()
			M.select_target(vim.api.nvim_get_current_buf())
		end, { desc = "Selects the target for the current buffer" })

		local active_possible_targets = {}
		for _, target in ipairs(targets) do
			if M.client_by_target[target] then
				table.insert(active_possible_targets, target)
			end
		end
		if #active_possible_targets == 1 then
			set_selected_target(bufnr, active_possible_targets[1])
		end
	end
	M.targets_by_bufnr[bufnr] = targets

	if get_selected_target(bufnr) == nil and #targets > 0 then
		M.select_target(vim.api.nvim_get_current_buf())
	end
end

local function get_client_by_name(client_name)
	local clients = vim.lsp.get_clients()
	for _, client in ipairs(clients) do
		if client.name == client_name then
			return client
		end
	end
	return nil
end

function M.attach_or_spawn(bufnr)
	
	
	
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local target = get_selected_target(bufnr)
	if target == nil then
		return
	elseif not util.path.is_file(target) then
		set_selected_target(bufnr, nil)
		return
	end

	local client = M.client_by_target[target]
	if client == nil then
		client = require("vm.razor.client").spawn(target, function()
			M.client_by_target[target] = nil
		end)
		if client == nil then
			vim.notify("Failed to start Razor client for " .. vim.fn.fnamemodify(target, ":~:."), vim.log.levels.ERROR)
			return
		end
		M.client_by_target[target] = client
	end
	--print(vim.inspect(client))
	--print(vim.inspect(bufnr))
	client:attach(bufnr )
	vim.lsp.buf_attach_client(bufnr, client.id )

	
	
end


function M.select_target(bufnr)
	vim.ui.select(M.targets_by_bufnr[bufnr], {
		prompt = "Select target",
	}, function(selected)
		set_selected_target(bufnr, selected)
		M.attach_or_spawn(bufnr)
	end)
end

function M.setup_autocmds()
	local lsp_group = vim.api.nvim_create_augroup("Razor", { clear = true })
	
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "razor" },
		--command = 'set filetype=razor',
		callback = function(opt)
			M.init_buf_targets(opt.buf)
			M.attach_or_spawn(opt.buf)
		end,
		group = lsp_group,
		desc = "",
	})
	
end



function M.setup_cmds()
	vim.api.nvim_create_user_command("RZComp", function()
		local api = vim.api
		local bufnr = api.nvim_get_current_buf()
		local c = get_client_by_name("roslyn")
		c.request("razor/initialize",vim.Nill, function(err, result)
			if err then
				  vim.lsp.log.warn(err.message)
			end
		end, vim.Nill)
	
	    --c.notify("razor/initialize",{})

		
		local lsp = vim.lsp
		local protocol = lsp.protocol
		local ms = protocol.Methods
		
		local clients = lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_completion })
		local remaining = #clients
		if remaining == 0 then
		  return findstart == 1 and -1 or {}
		end
	
		local util2 = vim.lsp.util
		
  		local clients = vim.lsp.buf_get_clients(bufnr)
		local win = api.nvim_get_current_win()
		local cursor = api.nvim_win_get_cursor(win)
		local lnum = cursor[1] - 1
		local cursor_col = cursor[2]
		local line = api.nvim_get_current_line()
		local line_to_cursor = line:sub(1, cursor_col)
		local client_start_boundary = vim.fn.match(line_to_cursor, '\\k*$') --[[@as integer]]
		local server_start_boundary = nil
		local items = {}

		local function on_done()
			local mode = api.nvim_get_mode()['mode']
			if mode == 'i' or mode == 'ic' then
			  vim.fn.complete((server_start_boundary or client_start_boundary) + 1, items)
			end
		end

		for _, client in pairs(clients) do
		  local params = util2.make_position_params(win, client.offset_encoding)
		--  print(vim.inspect(params))
		 -- print (params["textDocument"].uri)
		  local prms ={}
		  prms["uri"]=params["textDocument"].uri
		  prms["position"]=params["position"]
		  

		 

		  client.request("razor/languageQuery", prms, function(err, result)
			if err then
			  vim.lsp.log.warn(err.message)
			end
			if result and vim.fn.mode() == 'i' then
				local matches
				matches, server_start_boundary = M._convert_results(
				  line,
				  lnum,
				  cursor_col,
				  client_start_boundary,
				  server_start_boundary,
				  result,
				  client.offset_encoding
				)
				vim.list_extend(items, matches)
			  end
			  remaining = remaining - 1
			  if remaining == 0 then
				vim.schedule(on_done)
			  end
			
		  end, bufnr)
		end
		
	
	end, { desc = "Installs the roslyn server" })

	vim.keymap.set('n', '.', '<cmd>RZComp<cr>')
end



function M.setup(config)
	
	print("setup")
	M.setup_cmds()
	M.setup_autocmds()
	
end

return M