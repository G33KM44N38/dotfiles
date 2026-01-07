-- File: lua/local_plugin/lsp_profiler/init.lua
local M = {}

function M.start()
	for _, client in pairs(vim.lsp.get_clients()) do
		if not client._profiler_wrapped then
			client._profiler_wrapped = true
			local orig_notify = client.notify
			local orig_request = client.request

			-- Wrap request
			client.request = function(method, params, handler, bufnr)
				local start = vim.loop.hrtime()

				local new_handler = nil
				if handler then
					new_handler = function(err, result, ctx, config)
						local elapsed = (vim.loop.hrtime() - start) / 1e6
						if elapsed > 50 then
							vim.schedule(function()
								print(
									string.format(
										"[LSP Profiler] %s took %.2f ms (client: %s)",
										method,
										elapsed,
										client.name
									)
								)
							end)
						end
						handler(err, result, ctx, config)
					end
				end

				return orig_request(method, params, new_handler, bufnr)
			end

			-- Wrap notify
			client.notify = function(method, params)
				local start = vim.loop.hrtime()
				local result = orig_notify(method, params)
				local elapsed = (vim.loop.hrtime() - start) / 1e6

				if elapsed > 50 then
					vim.schedule(function()
						print(
							string.format(
								"[LSP Profiler] %s notify took %.2f ms (client: %s)",
								method,
								elapsed,
								client.name
							)
						)
					end)
				end

				return result
			end
		end
	end

	print("[LSP Profiler] Wrapped all active LSP clients safely.")
end

-- Setup function for lazy.nvim
function M.setup()
	-- Create command
	vim.api.nvim_create_user_command("LspProfile", function()
		M.start()
	end, { desc = "Start profiling LSP requests safely" })
end

return M
