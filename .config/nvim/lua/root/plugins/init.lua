return {
	{
		'echasnovski/mini.indentscope',
		version = false,
		config = function()
			require('mini.indentscope').setup()
		end
	},
	'nvim-lua/plenary.nvim',
	"tpope/vim-unimpaired",
	"ThePrimeagen/vim-be-good",
	"cdelledonne/vim-cmake",
	"junegunn/fzf.vim",
	"tpope/vim-surround",
	"rafi/awesome-vim-colorschemes",
	"tpope/vim-commentary",
	"tpope/vim-repeat",
	"tpope/vim-sensible",
	"voldikss/vim-floaterm",
	{
		'fatih/vim-go',
		keys = false,
		build = ':GoUpdateBinaries',
		config = function()
			vim.g.go_def_mapping_enabled = 0
			vim.g.go_doc_keywordprg_enabled = 0
		end,
	},
}
