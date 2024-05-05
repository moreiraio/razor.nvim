local util = require("lspconfig.util")

---@class RazorClient
---@field id number?
---@field target string
---@field private _bufnrs number[] | nil
local RazorClient = {}

function RazorClient:initialize()
	for _, bufnr in ipairs(self._bufnrs) do
		if not vim.lsp.buf_attach_client(bufnr, self.id) then
			local target = vim.fn.fnamemodify(self.target, ":~:.")
			local bufname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:.")
			vim.notify(string.format("Failed to attach Roslyn(%s) for %s", target, bufname), vim.log.levels.ERROR)
		end
	end
	self._bufnrs = nil
end

---Attaches(or schedules to attach) the client to a buffer
---@param self RazorClient
---@param bufnr integer
---@return boolean
function RazorClient:attach(bufnr)
	print("atach")
	print(vim.inspect(bufnr))
	if self._bufnrs then
		table.insert(self._bufnrs, bufnr)
		return true
	else
		return vim.lsp.buf_attach_client(bufnr, self.id)
	end
end

---@param target string
---@return RazorClient
function RazorClient.new(target)
	return setmetatable({
		target = target,

		id = nil,
		_bufnrs = {},
		_initialized = false,
	}, {
		__index = RazorClient,
	})
end

local function handle(handler)
	return function(err, res, ctx, config)
		return handler(err, res, ctx, config)
	end
end

local function handle_buffer_lines(err, lines)
    if err then
        print("Error loading buffer lines:", err)
        return
    end

    -- Do something with the lines, for example, print them
    for _, line in ipairs(lines) do
        print(line)
    end
end

local my_custom_default_definition = function(_, result, ctx, config)
	print("razor/initialize")
	--print(vim.inspect(result))
	--print(vim.inspect(ctx))
	--print(vim.inspect(config))
	return {""}
end
vim.lsp.handlers["razor/initialize"] = my_custom_default_definition

local M = {}

---Creates a new Roslyn lsp server
---@param cmd string
---@param target string
---@param on_attach function
---@param capabilities table
function M.spawn(target, on_exit)
   
	

	local target_uri = vim.uri_from_fname(target)

	print(vim.fn.getcwd())
	local cmp = require("cmp")
	local cmp_lsp = require("cmp_nvim_lsp")
	

	local capabilities = vim.lsp.protocol.make_client_capabilities()
	capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
	capabilities = vim.tbl_deep_extend('force', capabilities, {
		filetypes = { 'cs', 'razor' },
		workspace = {
		didChangeWatchedFiles = {
			dynamicRegistration = false,
		},
		},
	})
  
	--- Writes to error buffer.
	---@param ... string Will be concatenated before being written
	local function err_message(...)
		vim.notify(table.concat(vim.iter({ ... }):flatten():totable()), vim.log.levels.ERROR)
		api.nvim_command('redraw')
	end

	---@param table   table e.g., { foo = { bar = "z" } }
	---@param section string indicating the field of the table, e.g., "foo.bar"
	---@return any|nil setting value read from the table, or `nil` not found
	local function lookup_section(table, section)
		local keys = vim.split(section, '.', { plain = true }) --- @type string[]
		return vim.tbl_get(table, unpack(keys))
	end
		
	local spawned = RazorClient.new(target)
	local input = {
		['razor'] = {
			format = {
				enable = true,
				codeBlockBraceOnNextLine = false
			},
			completion = {
				commitElementsWithSpace = true
			}
		},
		['html']={
			autoClosingTags = true
		},
		['vs.editor.razor']={
			autoClosingTags = true
		}
	}
	local function intercept_completion(request, callback, context)
		print('Intercepting completion request:', vim.inspect(request))
		
		-- Implement custom logic here
		-- For example, modify or filter completion items
		
		-- Call the original completion request to continue normal behavior
		--callback(request, context)
	end

	local custom_commands = {
		-- Example command 'my_custom_command'
		my_custom_command = function(command, ctx)
			-- Your custom command logic here
			print("My custom command triggered!")
			-- You can access command and context data if needed
			print("Command:", command)
			print("Context:", vim.inspect(ctx))
		end,
		['textDocument/completion'] = function (command,ctx)
			print("hey hey")
		end
		-- Add more custom commands as needed
	}

	local html = {}  
	local autoClosingTags="autoClosingTags"
	html[autoClosingTags]=true

	---@diagnostic disable-next-line: missing-fields
	spawned.id = vim.lsp.start_client({
		name = "razor",
		capabilities = capabilities,
		--settings =  input,
							
							
								
							
					
										
			--	['vs.editor.razor']= {},
		--		['rust-analyzer'] = {},
			
		-- cmd = hacks.wrap_server_cmd(vim.lsp.rpc.connect("127.0.0.1", 8080)),
		cmd = { 
            vim.fn.expand("/Users/vitormoreira/.vscode/extensions/ms-dotnettools.csharp-2.23.15-darwin-arm64/.razor/rzls"),
                --vim.fn.expand("--logLevel"),
                --"0",
                vim.fn.expand("--projectConfigurationFileName"),
                "project.razor.vscode.bin",
                vim.fn.expand("--DelegateToCSharpOnDiagnosticPublish"),
                "true",
                vim.fn.expand("--UpdateBuffersForClosedDocuments"),
                "true",
                vim.fn.expand("--telemetryLevel"),
                "all",
                vim.fn.expand("--sessionId"),
                vim.fn.expand("1f839afa-c288-4995-8148-48ca90456c6d1712425155204"),
                vim.fn.expand("--telemetryExtensionPath"),
                vim.fn.expand("/Users/vitormoreira/.vscode/extensions/ms-dotnettools.csharp-2.23.15-darwin-arm64/.razortelemetry/Microsoft.VisualStudio.DevKit.Razor.dll"),
        },

		
		
		init_options = {
			AutomaticWorkspaceInit = true,
		},
		filetypes = {'cshtml','razor'},
		root_dir = vim.fn.getcwd(), ---@diagnostic disable-line: assign-type-mismatch
		on_init = function(client)
			vim.notify(
				"Razor client initialized for target " .. vim.fn.fnamemodify(target, ":~:."),
				vim.log.levels.INFO
			)

			client.notify("solution/open", {
				["solution"] = target_uri,
			})
			client.notify("razor/initialize",{})
			
		  

			
		end,
		on_attach = vim.schedule_wrap(function(client, bufnr)
			print("teste notify")

			


			
			-- Function to intercept completion requests
		end),
		commands= custom_commands,
		handlers = {
			
			["workspace/configuration"] = function(_, result, ctx)

				vim.notify("Roslyn project initialization complete", vim.log.levels.INFO)
				spawned:initialize()

				local client_id = ctx.client_id
				local client = vim.lsp.get_client_by_id(client_id)
				if not client then
				  err_message(
					'LSP[',
					client_id,
					'] client has shut down after sending a workspace/configuration request'
				  )
				  return
				end
				if not result.items then
				  return {}
				end
			  
				local response = {}
				for _, item in ipairs(result.items) do
				  if item.section then
					print(vim.inspect(item.section))
					local value = lookup_section(client.settings, item.section)
					-- For empty sections with no explicit '' key, return settings as is
					if value == nil and item.section == '' then
					  value = client.settings
					end
					if value == nil then
					  value = vim.NIL
					end
					table.insert(response, value)
				  end
				end
				print(vim.inspect(response))
				return response
			end,
            ["razor/csharpPullDiagnostics"] = function(_, result, ctx, config)
                --vim.notify("razor/csharpPullDiagnostics", vim.log.levels.ERROR)
                
				return vim.NIL
            end,
			["razor/initialize"] = function(_, result, ctx, config)
				print("razor/initialize")
				--print(vim.inspect(result))
				--print(vim.inspect(ctx))
				--print(vim.inspect(config))
				return
			end,
		},
		on_exit = on_exit,
	})

	if spawned.id == nil then
		return nil
	end
	
	return spawned
end

return M