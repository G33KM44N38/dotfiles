return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup({
				ui = {
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})
		end,
	},

	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					-- "ts_ls", -- REPLACED by typescript-tools.nvim
					-- "eslint", -- Disabled: using project-local ESLint via command line
					"tailwindcss",
					"html",
					"cssls",
					"jsonls",
					"dockerls",
					"clangd",
					"bashls",
					"yamlls",
					"gopls",
					"pyright",
					"prismals",
					"rust_analyzer",
				},
				automatic_installation = true,
			})
			-- ⚠️ Ne pas utiliser setup_handlers ici
		end,
	},

	{
		"pmizio/typescript-tools.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "williamboman/mason-lspconfig.nvim" },
		ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
		config = function()
			require("typescript-tools").setup({
				settings = {
					tsserver_max_memory = 1536,
					disable_solution_searching = false,
					publish_diagnostic_on = "insert_leave",
					separate_diagnostic_server = false,

					max_completion_entries = 25,
					include_automatic_completions = false,

					exclude_files = {
						"**/*.min.js",
						"**/*.generated.*",
						"**/node_modules/**",
						"**/dist/**",
						"**/build/**",
						"**/.next/**",
						"**/.turbo/**",
						"**/.expo/**",
						"**/test-results/**",
					},

					diagnostics = {
						enable = true,
					},
				},
				on_attach = function(client, bufnr)
					-- Get file size for performance optimization
					local filepath = vim.api.nvim_buf_get_name(bufnr)
					local ok, stats = pcall(vim.loop.fs_stat, filepath)
					local file_size = ok and stats and stats.size or 0
					local is_large_file = file_size > 100000 -- 100KB threshold

					if is_large_file then
						-- Disable expensive features for large files
						client.server_capabilities.semanticTokensProvider = nil
						client.server_capabilities.inlayHintProvider = nil
						vim.notify("LSP: Disabled heavy features for large file", vim.log.levels.WARN)
					end
				end,
			})
		end,
	},

	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},

	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
			"saghen/blink.cmp",
			{ "antosha417/nvim-lsp-file-operations", config = true },
		},
		config = function()
			local blink_cmp = require("blink.cmp")
			local capabilities = blink_cmp.get_lsp_capabilities()

			-- vim.diagnostic.config({
			-- 	virtual_text = {
			-- 		prefix = "● ", -- Prefix for inline errors
			-- 		spacing = 1,
			-- 	},
			-- 	signs = true,
			-- 	underline = true,
			-- 	update_in_insert = false, -- Let tsserver complete full analysis before showing
			-- 	severity_sort = true,
			-- })

			----------------------------------------------------
			-- LUA LS
			----------------------------------------------------
			vim.lsp.config("lua_ls", {
				capabilities = capabilities,
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
						workspace = {
							library = vim.api.nvim_get_runtime_file("", true),
							checkThirdParty = false,
						},
						telemetry = { enable = false },
					},
				},
			})

			----------------------------------------------------
			-- TYPESCRIPT (now handled by typescript-tools.nvim plugin above)
			-- The configuration is in the typescript-tools.setup() call
			----------------------------------------------------

			----------------------------------------------------
			-- ESLINT (Disabled)
			-- Using project-local ESLint via command line (npm run lint) instead of LSP
			-- Reason: ESLint LSP can't find local node_modules libraries reliably
			----------------------------------------------------
			-- vim.lsp.config("eslint", {
			-- 	capabilities = capabilities,
			-- 	root_dir = vim.fs.root(0, {
			-- 		".eslintrc.js",
			-- 		".eslintrc.cjs",
			-- 		".eslintrc.json",
			-- 		"eslint.config.js",
			-- 		"eslint.config.mjs",
			-- 	}),
			-- 	single_file_support = false,
			-- })

			----------------------------------------------------
			-- TAILWIND
			----------------------------------------------------
			local tailwind_excluded_patterns = {
				"%.test%.",
				"%.spec%.",
				"/e2e/",
			}

			local function should_disable_tailwind(bufnr)
				local filepath = vim.api.nvim_buf_get_name(bufnr)
				for _, pattern in ipairs(tailwind_excluded_patterns) do
					if filepath:match(pattern) then
						return true
					end
				end
				return false
			end

			vim.lsp.config("tailwindcss", {
				capabilities = capabilities,
				single_file_support = false,
				-- Avoid attaching on test/e2e files entirely; detaching after attach
				-- can leave Neovim's LSP change tracking out of sync on 0.11.6.
				root_dir = function(bufnr, on_dir)
					if should_disable_tailwind(bufnr) then
						return
					end

					local root = vim.fs.root(bufnr, {
						"tailwind.config.js",
						"tailwind.config.cjs",
						"tailwind.config.mjs",
						"tailwind.config.ts",
						"postcss.config.js",
						"package.json",
						".git",
					})
					if root then
						on_dir(root)
					end
				end,
				settings = {
					tailwindCSS = {
						classFunctions = { "tw" },
						experimental = {
							classRegex = {
								{ "tw%s*`([^`]*)`", 1 },
							},
						},
					},
				},
			})

			vim.lsp.enable("tailwindcss")

			----------------------------------------------------
			-- SERVEURS SIMPLES
			----------------------------------------------------
			local simple_servers = {
				"html",
				"cssls",
				"jsonls",
				"dockerls",
				"clangd",
				"bashls",
				"yamlls",
				"gopls",
				"pyright",
				"prismals",
				"rust_analyzer",
			}

			for _, server in ipairs(simple_servers) do
				vim.lsp.config(server, {
					capabilities = capabilities,
				})
			end

			----------------------------------------------------
			-- PROTECTION CONTRE LES DOUBLONS
			----------------------------------------------------
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("LspCleanupDuplicates", { clear = true }),
				callback = function(args)
					vim.defer_fn(function()
						local bufnr = args.buf
						local clients = vim.lsp.get_clients({ bufnr = bufnr })

						-- Group clients by name AND root directory to avoid detaching legitimate separate instances
						local by_name_and_root = {}
						for _, client in ipairs(clients) do
							local root_dir = client.config.root_dir or "no_root"
							local key = client.name .. "|" .. root_dir
							by_name_and_root[key] = by_name_and_root[key] or {}
							table.insert(by_name_and_root[key], client)
						end

						-- Detach true duplicates (same name AND same root directory)
						for key, client_list in pairs(by_name_and_root) do
							if #client_list > 1 then
								table.sort(client_list, function(a, b)
									return a.id < b.id
								end)

								for i = 1, #client_list - 1 do
									-- Safe detachment with proper validation
									if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
										pcall(function()
											vim.lsp.buf_detach_client(bufnr, client_list[i].id)
										end)
									end
									vim.schedule(function()
										local name, root = key:match("^(.-)|(.*)$")
										print(
											string.format(
												"🧹 Detached duplicate %s (id: %d) for root: %s",
												name,
												client_list[i].id,
												root
											)
										)
									end)
								end
							end
						end

						-- Désactiver GraphQL s'il spawn malgré tout
						for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
							if client.name == "graphql" then
								-- Safe detachment with proper validation
								if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
									pcall(function()
										vim.lsp.buf_detach_client(bufnr, client.id)
									end)
								end
								vim.schedule(function()
									print("🚫 Blocked graphql (not configured)")
								end)
							end
						end
					end, 200)
				end,
			})

			----------------------------------------------------
			-- COMMANDES UTILITAIRES
			----------------------------------------------------
			vim.api.nvim_create_user_command("LspClients", function()
				local clients = vim.lsp.get_clients({ bufnr = 0 })
				print(string.format("\n📋 Active LSP clients (%d):", #clients))
				for _, client in ipairs(clients) do
					local root = client.config.root_dir or "no root"
					print(string.format("  %d. %s → %s", client.id, client.name, root))
				end
			end, {})

			vim.api.nvim_create_user_command("LspKill", function(opts)
				local client_id = tonumber(opts.args)
				if client_id then
					vim.lsp.stop_client(client_id)
					print("🔪 Killed LSP client " .. client_id)
				else
					print("Usage: :LspKill <client_id>")
				end
			end, { nargs = 1 })

			----------------------------------------------------
			-- ESLINT COMMAND (using local installation)
			----------------------------------------------------
			vim.api.nvim_create_user_command("Eslint", function()
				local filepath = vim.api.nvim_buf_get_name(0)
				if filepath == "" then
					vim.notify("No file open!", vim.log.levels.ERROR)
					return
				end

				vim.notify("Running ESLint...", vim.log.levels.INFO)
				vim.fn.jobstart({
					"./node_modules/.bin/eslint",
					"--fix",
					vim.fn.expand("%:p"),
				}, {
					on_exit = function(job, exit_code)
						if exit_code == 0 then
							vim.notify("ESLint: No errors found ✓", vim.log.levels.INFO)
							vim.cmd("edit!") -- Reload fixed file
						elseif exit_code == 1 then
							vim.notify("ESLint: Errors found - check quickfix", vim.log.levels.WARNING)
							vim.cmd("copen") -- Show errors in quickfix
						else
							vim.notify("ESLint: Command failed (exit code " .. exit_code .. ")", vim.log.levels.ERROR)
						end
					end,
				})
			end, {})
		end,
	},

	----------------------------------------------------
	-- MEMORY MANAGEMENT PLUGINS (DISABLED for stability)
	-- These were causing LSP to stop after edits and hover commands
	----------------------------------------------------
	-- {
	-- 	"hinell/lsp-timeout.nvim",
	-- 	event = "VeryLazy",
	-- 	config = function()
	-- 		-- lsp-timeout uses global config (no setup function)
	-- 		vim.g.lspTimeoutConfig = {
	-- 			stopTimeout = 180000, -- 3 minutes idle timeout (conservative for testing)
	-- 			startTimeout = 60000, -- Start after 1 minute of focus
	-- 			silent = true, -- Don't notify on stop/start
	-- 			filetypes = {
	-- 				ignore = { -- Don't manage LSP for these filetypes
	-- 					"markdown",
	-- 					"text",
	-- 					"dockerfile",
	-- 					"yml",
	-- 					"yaml",
	-- 					"json",
	-- 					"html",
	-- 					"css",
	-- 				},
	-- 			},
	-- 		}
	-- 	end,
	-- },

	-- {
	-- 	"Zeioth/garbage-day.nvim",
	-- 	event = "VeryLazy",
	-- 	config = function()
	-- 		require("garbage-day").setup({
	-- 			aggressive_mode = false, -- Conservative mode for testing
	-- 			cleanup_interval = 180000, -- Check every 3 minutes
	-- 			excluded_servers = { "lua_ls" }, -- Keep Lua LSP running
	-- 			notify_on_cleanup = false,
	-- 		})
	-- 	end,
	-- },
}
