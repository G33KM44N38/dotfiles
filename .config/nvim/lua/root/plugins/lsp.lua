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
				-- ✅ INSTALLER les serveurs mais NE PAS les démarrer automatiquement
				ensure_installed = {
					"lua_ls",
					"ts_ls",
					"eslint",
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
					-- ❌ PAS "graphql" ici - vous ne l'utilisez pas
				},
				automatic_installation = true,
			})

			-- ⚠️ CRITIQUE: Ne PAS appeler :setup_handlers()
			-- ⚠️ CRITIQUE: Ne PAS utiliser handlers = { ... }
			-- Laisser mason-lspconfig JUSTE installer les binaires
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
			local lspconfig = require("lspconfig")
			local blink_cmp = require("blink.cmp")
			local capabilities = blink_cmp.get_lsp_capabilities()

			vim.diagnostic.config({
				virtual_text = false,
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
			})

			-- ========================================
			-- Configuration MANUELLE des serveurs
			-- ========================================

			-- Lua (Neovim development)
			lspconfig.lua_ls.setup({
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

			-- TypeScript/JavaScript
			lspconfig.ts_ls.setup({
				capabilities = capabilities,
				root_dir = lspconfig.util.root_pattern("package.json"),
				single_file_support = false,
			})

			-- ESLint (seulement si config existe)
			lspconfig.eslint.setup({
				capabilities = capabilities,
				root_dir = lspconfig.util.root_pattern(
					".eslintrc.js",
					".eslintrc.cjs",
					".eslintrc.json",
					"eslint.config.js",
					"eslint.config.mjs"
				),
				single_file_support = false,
			})

			-- Tailwind (seulement si config existe)
			lspconfig.tailwindcss.setup({
				capabilities = capabilities,
				root_dir = lspconfig.util.root_pattern(
					"tailwind.config.js",
					"tailwind.config.ts",
					"tailwind.config.cjs",
					"tailwind.config.mjs"
				),
				single_file_support = false,
				on_attach = function(client, bufnr)
					-- Bloquer sur fichiers de test
					local filepath = vim.api.nvim_buf_get_name(bufnr)
					if filepath:match("%.test%.") or filepath:match("%.spec%.") or filepath:match("/e2e/") then
						vim.lsp.buf_detach_client(bufnr, client.id)
						return
					end
					-- Désactiver l'autocomplétion générale
					client.server_capabilities.completionProvider = false
				end,
			})

			-- GraphQL - COMPLÈTEMENT DÉSACTIVÉ
			-- Décommentez SEULEMENT si vous avez un .graphqlrc
			-- lspconfig.graphql.setup({
			-- 	capabilities = capabilities,
			-- 	filetypes = { "graphql", "gql" },
			-- 	root_dir = lspconfig.util.root_pattern(".graphqlrc", ".graphqlrc.yml", "graphql.config.js"),
			-- })

			-- Autres serveurs (configuration simple)
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
				lspconfig[server].setup({
					capabilities = capabilities,
				})
			end

			-- ========================================
			-- Protection anti-doublons AGGRESSIVE
			-- ========================================
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("LspCleanupDuplicates", { clear = true }),
				callback = function(args)
					-- Attendre que tous les serveurs s'attachent
					vim.defer_fn(function()
						local bufnr = args.buf
						local clients = vim.lsp.get_clients({ bufnr = bufnr })

						-- Grouper par nom
						local by_name = {}
						for _, client in ipairs(clients) do
							by_name[client.name] = by_name[client.name] or {}
							table.insert(by_name[client.name], client)
						end

						-- Détacher les doublons (garder le plus récent)
						for name, client_list in pairs(by_name) do
							if #client_list > 1 then
								table.sort(client_list, function(a, b)
									return a.id < b.id
								end)

								for i = 1, #client_list - 1 do
									vim.lsp.buf_detach_client(bufnr, client_list[i].id)
									vim.schedule(function()
										print(
											string.format(
												"🧹 Detached duplicate %s (id: %d)",
												name,
												client_list[i].id
											)
										)
									end)
								end
							end
						end

						-- Bloquer GraphQL s'il apparaît quand même
						for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
							if client.name == "graphql" then
								vim.lsp.buf_detach_client(bufnr, client.id)
								vim.schedule(function()
									print("🚫 Blocked graphql (not configured)")
								end)
							end
						end
					end, 100)
				end,
			})

			-- ========================================
			-- Commandes de diagnostic
			-- ========================================
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
		end,
	},
}
