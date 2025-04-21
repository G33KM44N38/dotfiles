return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {},
	config = function()
		vim.api.nvim_set_keymap("n", "<C-p>", "<cmd>FzfLua files<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<C-s>", "<cmd>FzfLua live_grep<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "<leader>ke", "<cmd>FzfLua keymaps<CR>",
			{ noremap = true, silent = true })
	end
}
