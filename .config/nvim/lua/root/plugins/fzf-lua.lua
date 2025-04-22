return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {},
	config = function()
		vim.api.nvim_set_keymap("n", "gi", "<cmd>FzfLua lsp_implementations<CR>", Opts)
		vim.api.nvim_set_keymap("n", "gd", "<cmd>FzfLua lsp_definitions<CR>", Opts)
		vim.api.nvim_set_keymap("n", "gr", "<cmd>FzfLua lsp_references<CR>", Opts)
		vim.api.nvim_set_keymap("n", "<C-p>", "<cmd>FzfLua files<CR>", Opts)
		vim.api.nvim_set_keymap("n", "<C-s>", "<cmd>FzfLua live_grep<CR>", Opts)
		vim.api.nvim_set_keymap("n", "<leader>ke", "<cmd>FzfLua keymaps<CR>",
			{ noremap = true, silent = true })
	end
}
