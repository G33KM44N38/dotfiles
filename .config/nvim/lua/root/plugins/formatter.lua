local javascript_formatter = {
	"eslint_d",
	"prettier",
}

return {
	"stevearc/conform.nvim",
	lazy = true,
	event = { "BufReadPre", "BufNewFile", "InsertLeave" },
	dependencies = {
		"williamboman/mason.nvim",
		{
			"zapling/mason-conform.nvim",
			dependencies = { "williamboman/mason.nvim", "stevearc/conform.nvim" },
			config = function()
				require("mason-conform").setup({})
			end,
		},
	},
	config = function()
		local conform = require("conform")
		conform.setup({
			formatters = {
				prettier = {
					-- This tells conform to run prettier from the project root directory,
					-- which helps it find the project-specific prettier config and executable.
					require_cwd = true,
				},
			},
			formatters_by_ft = {
				javascript = javascript_formatter,
				typescript = javascript_formatter,
				javascriptreact = javascript_formatter,
				typescriptreact = javascript_formatter,
				svelte = javascript_formatter,
				lua = { "stylua" },
				yaml = { "prettier" }, -- <--- add this line for YAML formatting
				yml = { "prettier" }, -- <--- also add this to catch `.yml` files
			},
			format_after_save = {
				lsp_fallback = true,
				async = true,
				timeout_ms = 2000,
			},
		})

		vim.keymap.set({ "n", "v" }, "<leader>lf", function()
			conform.format({
				lsp_fallback = true,
				async = true,
				timeout_ms = 10000,
			})
		end, { desc = "Format file or range (in visual mode)" })

		vim.api.nvim_create_user_command("FormatDisable", function(args)
			if args.bang then
				vim.b.disable_autoformat = true
			else
				vim.g.disable_autoformat = true
			end
		end, { desc = "Disable autoformat-on-save", bang = true })

		vim.api.nvim_create_user_command("FormatEnable", function()
			vim.b.disable_autoformat = false
			vim.g.disable_autoformat = false
		end, { desc = "Re-enable autoformat-on-save" })
	end,
}
