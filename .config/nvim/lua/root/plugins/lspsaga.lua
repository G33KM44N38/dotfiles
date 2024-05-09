return {
	"glepnir/lspsaga.nvim",
	branch = "main",
	config = function()
		local opts = { noremap = true, silent = true }
		vim.keymap.set("n", "<leader>gr", "<cmd>Lspsaga rename<CR>", opts)
		vim.keymap.set("n", "gD", "<cmd>Lspsaga finder<CR>", opts)
		vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts) -- show documentation for what is under cursor
		require('lspsaga').setup({})
	end,
}
