return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
	},
	config = function()
		-- import lspconfig plugin
		local lspconfig = require("lspconfig")

		-- import cmp-nvim-lsp plugin
		local cmp_nvim_lsp = require("cmp_nvim_lsp")


		local keymap = vim.keymap -- for conciseness

		local opts = { noremap = true, silent = true }
		local on_attach = function(client, bufnr)
			opts.buffer = bufnr
			-- set keybinds
			opts.desc = "Show LSP references"
			keymap.set("n", "gD", "<cmd>Lspsaga finder<CR>", opts)

			opts.desc = "Go to declaration"
			keymap.set("n", "gR", vim.lsp.buf.declaration, opts) -- go to declaration

			opts.desc = "Show LSP implementations"
			keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts) -- show lsp implementations

			opts.desc = "Show LSP type definitions"
			keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type definitions

			opts.desc = "Smart rename"
			keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts) -- smart rename

			opts.desc = "Show buffer diagnostics"
			keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file

			opts.desc = "Show line diagnostics"
			keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line

			opts.desc = "Show documentation for what is under cursor"
			keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

			opts.desc = "Restart LSP"
			keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary
		end

		-- used to enable autocompletion (assign to every lsp server config)
		local capabilities = cmp_nvim_lsp.default_capabilities()

		-- Change the Diagnostic symbols in the sign column (gutter)
		-- (not in youtube nvim video)
		local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		-- configure html server
		lspconfig["html"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
			filetypes = { "html" },
		})

		-- configure bash server with plugin
		lspconfig["bashls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
			filetypes = { "sh" },
		})

		-- configure docker server with plugin
		lspconfig["dockerls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure docker-compose server with plugin
		lspconfig["docker_compose_language_service"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure css server
		lspconfig["cssls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure C language server
		lspconfig["clangd"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure python server
		lspconfig["jsonls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})


		-- configure yamlls server
		lspconfig["yamlls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure lua_ls server
		lspconfig["lua_ls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure bashls server
		lspconfig["bashls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})


		-- configure gopls server
		lspconfig["gopls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure lua server (with special settings)
		lspconfig["lua_ls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
			settings = { -- custom settings for lua
				Lua = {
					-- make the language server recognize "vim" global
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						-- make language server aware of runtime files
						library = {
							[vim.fn.expand("$VIMRUNTIME/lua")] = true,
							[vim.fn.stdpath("config") .. "/lua"] = true,
						},
					},
				},
			},
		})

		lspconfig["eslint"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["ts_ls"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["tailwindcss"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["pyright"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["volar"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["solang"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["solidity"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["graphql"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,

		})

		lspconfig["prismals"].setup({
			-- capabilities = capabilities,
			on_attach = on_attach,

		})
	end,
}
