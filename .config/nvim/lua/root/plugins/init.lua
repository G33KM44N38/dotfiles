return {
	"ThePrimeagen/vim-be-good",
	"cdelledonne/vim-cmake",
	"junegunn/fzf.vim",
	"kabouzeid/nvim-lspinstall",
	"rafi/awesome-vim-colorschemes",
	"tpope/vim-commentary",
	"tpope/vim-repeat",
	"tpope/vim-sensible",
	"tpope/vim-surround",
	"tpope/vim-unimpaired",
	"voldikss/vim-floaterm",
	"williamboman/nvim-lsp-installer",
	"windwp/nvim-autopairs",
	"windwp/nvim-ts-autotag",
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
