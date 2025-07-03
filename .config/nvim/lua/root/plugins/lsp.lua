local options = require("vim.filetype.options")
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
			if vim.g.vscode then
				return
			end
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
					-- "volar",
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
			local opts = { buffer = bufnr }

			local capabilities = cmp_nvim_lsp.default_capabilities()

			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
			end

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", {}),
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if client and (client.name == "eslint" or client.name == "eslint_d") then
						vim.api.nvim_create_autocmd("BufWritePre", {
							buffer = args.buf,
							callback = function()
								vim.lsp.buf.format({ async = true, filter = function(client) return client.name == "eslint" or client.name == "eslint_d" end })
							end,
						})
					end
				end,
			})

			vim.diagnostic.config({
				virtual_text = false,
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
			})
		end,
	},
}
