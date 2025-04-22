return {
	"nvimdev/lspsaga.nvim",
	branch = "main",
	config = function()
		require('lspsaga').setup({})
		vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", Opts) -- show documentation for what is under cursor

		vim.keymap.set('n', ']d', "<cmd>Lspsaga diagnostic_jump_next<CR>",
			{ desc = 'Go to previous [D]iagnostic message' })
		vim.keymap.set('n', '[d', "<cmd>Lspsaga diagnostic_jump_prev<CR>", { desc = 'Go to next [D]iagnostic message' })

		vim.keymap.set({ "n", "v" }, '<leader>c', "<cmd>Lspsaga code_actions<CR>",
			{ desc = 'Go to next [D]iagnostic message' })
	end,
}
