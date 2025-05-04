return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		files = {
			-- Use 'fd' with exclude options
			cmd = "fd --type f --hidden --exclude node_modules --exclude dist",
		},
		grep = {
			-- Use 'rg' with glob exclude patterns
			rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob '!node_modules/*' --glob '!dist/*'",
		},
	},
	config = function()
		local fzf = require("fzf-lua")
		local opts = { noremap = true, silent = true }

		vim.api.nvim_set_keymap("n", "gi", "<cmd>FzfLua lsp_implementations<CR>", opts)
		vim.api.nvim_set_keymap("n", "gd", "<cmd>FzfLua lsp_definitions<CR>", opts)
		vim.api.nvim_set_keymap("n", "gr", "<cmd>FzfLua lsp_references<CR>", opts)
		vim.api.nvim_set_keymap("n", "<C-p>", "<cmd>FzfLua files<CR>", opts)
		vim.api.nvim_set_keymap("n", "<C-s>", "<cmd>FzfLua grep<CR>", opts)
		vim.api.nvim_set_keymap("n", "<leader>ke", "<cmd>FzfLua keymaps<CR>", opts)
		vim.keymap.set({ "n", "v" }, "<leader>c", "<cmd>FzfLua lsp_code_actions<CR>", { desc = "Code Actions" })
	end,
}
