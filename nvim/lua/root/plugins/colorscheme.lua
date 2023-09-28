return {
	"bluz71/vim-nightfly-guicolors",
	priority = 1000,
	config = function()
		vim.cmd([[colorscheme nightfly]])
		-- vim.cmd('colorscheme solarized8_high')
		-- vim.cmd('colorscheme gruvbox')
		-- vim.cmd('colorscheme alduin')
		-- vim.cmd('colorscheme iceberg')
		-- vim.cmd('colorscheme gotham')
	end,
}
