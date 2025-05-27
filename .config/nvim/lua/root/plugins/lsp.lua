return {
	{
		"williamboman/mason.nvim",
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
			{
				"folke/lazydev.nvim",
				ft = "lua",
				opts = {
					library = {
						{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
					},
				},
			},
		},
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

			require("mason-lspconfig").setup({
				automatic_enable = {
					"lua_ls",
					"tailwindcss",
					"ts_ls",
					"html",
					"cssls",
					"jsonls",
					"dockerls",
					"clangd",
					"bashls",
					"yamlls",
					"eslint",
					"gopls",
					"pyright",
					"volar",
					"prismals",
					"graphql",
					"rust_analyzer",
				},
				ensure_installed = {
					"lua_ls",
					"tailwindcss",
					"ts_ls",
					"html",
					"cssls",
					"jsonls",
					"dockerls",
					"clangd",
					"bashls",
					"yamlls",
					"eslint",
					"gopls",
					"pyright",
					"volar",
					"prismals",
					"graphql",
					"rust_analyzer",
				},
				automatic_installation = true,
			})
		end,
	},

	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			{ "antosha417/nvim-lsp-file-operations", config = true },
		},
		config = function()
			local lspconfig = require("lspconfig")
			local cmp_nvim_lsp = require("cmp_nvim_lsp")

			local on_attach = function(client, bufnr)
				local opts = { buffer = bufnr }

				vim.keymap.set("n", "gD", "<cmd>Lspsaga finder<CR>", opts)
				vim.keymap.set("n", "gR", vim.lsp.buf.declaration, opts)
				vim.keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)
				vim.keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts)
				vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
				vim.keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts)
				vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)

				-- Auto-fix on save for ESLint
				if client.name == "eslint" then
					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = bufnr,
						command = "EslintFixAll",
					})
				end
			end

			local capabilities = cmp_nvim_lsp.default_capabilities()

			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				-- vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
			end

			vim.diagnostic.config({
				virtual_text = false,
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
			})

			-- Configuration par serveur
			lspconfig.lua_ls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			-- lspconfig.ts_ls.setup({
			-- 	capabilities = capabilities,
			-- 	on_attach = on_attach,
			-- 	root_dir = require("lspconfig.util").root_pattern("tsconfig.json", "package.json", ".git"),
			-- })

			lspconfig.eslint.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			-- lspconfig.volar.setup({
			-- 	capabilities = capabilities,
			-- 	on_attach = on_attach,
			-- 	filetypes = { "vue" },
			-- })

			lspconfig.tailwindcss.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.html.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.cssls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.jsonls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.dockerls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.docker_compose_language_service = nil -- pas toujours stable

			lspconfig.clangd.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.bashls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.yamlls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.gopls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
				settings = {
					gopls = {
						analyses = {
							unusedparams = true,
						},
						staticcheck = true,
					},
				},
			})

			lspconfig.pyright.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.rust_analyzer.setup({
				capabilities = capabilities,
				on_attach = on_attach,
				settings = {
					["rust-analyzer"] = {
						cargo = { allFeatures = false },
						procMacro = { enable = false },
						checkOnSave = { command = "clippy" },
					},
				},
			})

			lspconfig.graphql.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			lspconfig.prismals.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})
		end,
	},
}
