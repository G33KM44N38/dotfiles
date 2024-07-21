return {
	"vim-test/vim-test",
	dependencies = { "preservim/vimux" },
	config = function()
		-- Set vim-test strategy
		vim.g['test#strategy'] = 'vimux'

		-- Define keymappings
		local map = vim.api.nvim_set_keymap
		local opts = { noremap = true, silent = true }

		map('n', '<leader>TVP', ':TestFile -v -parallel=2<CR>', opts)
		map('n', '<leader>tv', ':TestNearest -v<CR>', opts)
		map('n', '<leader>t', ':TestNearest<CR>', opts)
		map('n', '<leader>TV', ':TestFile -v<CR>', opts)
		map('n', '<leader>T', ':TestFile<CR>', opts)
		map('n', '<leader>TA', ':TestSuite<CR>', opts)
		map('n', '<leader>l', ':TestLast<CR>', opts)
	end
}
