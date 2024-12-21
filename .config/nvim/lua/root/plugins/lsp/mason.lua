return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		{
			"folke/lazydev.nvim",
			ft = "lua", -- only load on lua files
			opts = {
				library = {
					-- See the configuration section for more details
					-- Load luvit types when the `vim.uv` word is found
					{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				},
			},
		},
	},
	config = function()
		-- import mason
		local mason = require("mason")

		--import mason-lspconfig
		local mason_lspconfig = require("mason-lspconfig")

		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗"
				}
			}
		})

		mason_lspconfig.setup({
			-- list of servers for mason to install
			ensure_installed = {
				"tailwindcss",
				"ts_ls",
				"html",
				"cssls",
				"lua_ls",
				"jsonls",
				"dockerls",
				"docker_compose_language_service",
				"clangd",
				"bashls",
				"yamlls",
				"eslint",
				"bashls",
				"gopls",
				"pyright",
				"volar",
				"solang",
				"solidity",
				"prismals",
				"graphql",
				"rust_analyzer"
			},
			-- auto-install configured servers (with lspconfig)
			automatic_installation = true, -- not the same as ensure_installed
		})
	end,
}
