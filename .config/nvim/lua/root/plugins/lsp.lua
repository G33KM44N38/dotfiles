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
			"saghen/blink.cmp",
			{ "antosha417/nvim-lsp-file-operations", config = true },
		},
		config = function()
			local lspconfig = require("lspconfig")
			local blink_cmp = require("blink.cmp")
			local opts = { buffer = bufnr }

			local capabilities = blink_cmp.get_lsp_capabilities()

			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
			end

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", {}),
				callback = function()
					vim.lsp.buf.code_action({
						context = { only = { "source.fixAll.eslint" } },
						apply = true,
					})
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
