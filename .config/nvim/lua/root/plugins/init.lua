return {
	"kabouzeid/nvim-lspinstall",
	{
		'fatih/vim-go',
		keys = false,
		build = ':GoUpdateBinaries',
		config = function()
			vim.g.go_def_mapping_enabled = 0
			vim.g.go_doc_keywordprg_enabled = 0
		end,
	},
	'ThePrimeagen/harpoon',
	'ThePrimeagen/vim-be-good',
	'windwp/nvim-autopairs',
	'windwp/nvim-ts-autotag',
	'SirVer/ultisnips',
	'cdelledonne/vim-cmake',
	'rafi/awesome-vim-colorschemes',
	'tpope/vim-commentary',
	'tpope/vim-surround',
	"voldikss/vim-floaterm",
	'williamboman/nvim-lsp-installer',
}
