return {
	"bluz71/vim-nightfly-guicolors",
	priority = 1000,
	config = function()
		-- Lua initialization file
		vim.g.nightflyTransparent = true
		vim.g.nightflyVirtualTextColor = true
		vim.cmd([[colorscheme nightfly]])

		vim.api.nvim_set_hl(0, "LineNr", { fg = "white" })

		-- vim.o.background = "light"
		-- vim.cmd('colorscheme gruvbox')

		-- vim.cmd('colorscheme solarized8_high')
		-- vim.cmd('colorscheme gruvbox')
		-- vim.cmd([[colorscheme alduin]])
		-- vim.cmd([[colorscheme solarized8_high]])
		-- vim.cmd('colorscheme iceberg')
		-- vim.cmd([[colorscheme gotham]])
		-- vim.cmd([[colorscheme papercolor]])
		-- vim.cmd([[colorscheme mountaineer]])
		-- vim.cmd([[colorscheme onedark]])
		-- vim.cmd([[colorscheme sierra]])
		-- vim.cmd([[colorscheme termschool]])
		-- vim.cmd([[colorscheme molokai]])
		-- vim.cmd([[colorscheme 256_noir]])
		-- vim.cmd([[colorscheme atom]])
	end,
}
