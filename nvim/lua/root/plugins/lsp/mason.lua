return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
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
        "tsserver",
        "html",
        "cssls",
        "tailwindcss",
        "svelte",
        "lua_ls",
        "emmet_ls",
        "pyright"
      },
      -- auto-install configured servers (with lspconfig)
      automatic_installation = true, -- not the same as ensure_installed
    })

    -- mason_null_ls.setup({
    --   -- list of formatters & linters for mason to install
    --   ensure_installed = {
    --     "prettier", -- ts/js formatter
    --     "stylua", -- lua formatter
    --     "eslint_d", -- ts/js linter
    --   },
    --   -- auto-install configured servers (with lspconfig)
    --   automatic_installation = true,
    -- })
	end,
}
