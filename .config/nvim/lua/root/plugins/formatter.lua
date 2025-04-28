local javascript_formatter= {
	"prettier",
	"ts_ls"
}
return {
	"stevearc/conform.nvim",
	dependencies = { "mason.nvim" },
	lazy = true,
	event = { "BufReadPre", "BufNewFile", "InsertLeave" },
	config = function()
		local conform = require("conform")
		conform.setup({
			formatters_by_ft = {
				javascript = javascript_formatter,
				typescript = javascript_formatter,
				javascriptreact = javascript_formatter,
				typescriptreact = javascript_formatter,
				svelte = javascript_formatter,
				-- css = { "prettier" },
				-- html = { "prettier" },
				-- json = { "prettier" },
				-- yaml = { "prettier" },
				-- markdown = { "prettier" },
				-- graphql = { "prettier" },
				lua = { "stylua" },
				-- python = { "isort", "black" },
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
		end, {
			desc = "Disable autoformat-on-save",
			bang = true,
		})
		vim.api.nvim_create_user_command("FormatEnable", function()
			vim.b.disable_autoformat = false
			vim.g.disable_autoformat = false
		end, {
			desc = "Re-enable autoformat-on-save",
		})
	end,
	{
		"zapling/mason-conform.nvim",
		dependencies = { "williamboman/mason.nvim", "stevearc/conform.nvim" },
		config = function()
			require("mason-conform").setup({
				-- Optionally, specify formatters to ignore during installation
				-- ignore_install = { "prettier" },
			})
		end,
	},
}
