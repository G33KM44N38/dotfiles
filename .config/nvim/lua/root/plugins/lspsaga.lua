return {
	"nvimdev/lspsaga.nvim",
	branch = "main",
	config = function()
		require('lspsaga').setup({})
		local opts = { noremap = true, silent = true }
		vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts) -- show documentation for what is under cursor
		vim.keymap.set("n", 'gr', "<cmd>Lspsaga finder<CR>", opts)
		vim.keymap.set("n", "gd", "<cmd>Lspsaga goto_definition<CR>", opts)


		vim.keymap.set('n', ']d', "<cmd>Lspsaga diagnostic_jump_next<CR>",
			{ desc = 'Go to previous [D]iagnostic message' })
		vim.keymap.set('n', '[d', "<cmd>Lspsaga diagnostic_jump_prev<CR>", { desc = 'Go to next [D]iagnostic message' })

		vim.keymap.set({ "n", "v" }, '<leader>c', "<cmd>Lspsaga code_actions<CR>",
			{ desc = 'Go to next [D]iagnostic message' })
	end,
}
