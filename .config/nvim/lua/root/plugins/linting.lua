return {
	"mfussenegger/nvim-lint",
	event = {
		"BufReadPre",
		"BufNewFile",
	},
	config = function()
		local lint = require("lint")

		lint.linters_by_ft = {
			javascript = { "eslint" },
			typescript = { "eslint" },
			typescriptreact = { "eslint" },
			javascriptreact = { "eslint" },
		}

		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

		vim.api.nvim_create_autocmd({ "TextChanged" },
			{
				group = lint_augroup,
				callback = function()
					lint.try_lint()
				end
			})

		vim.keymap.set("n", "<leader>lt", function()
			lint.try_lint()
		end, { desc = "Trigger linting for current file" })
	end
}
