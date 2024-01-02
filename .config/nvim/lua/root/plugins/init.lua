return {
	"kabouzeid/nvim-lspinstall",
	"onsails/lspkind.nvim",
	'nvim-lua/plenary.nvim',
	'preservim/vimux',
	'vim-test/vim-test',
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
	'akinsho/bufferline.nvim',
	'SirVer/ultisnips',
	'cdelledonne/vim-cmake',
	'rafi/awesome-vim-colorschemes',
	'tpope/vim-commentary',
	'tpope/vim-surround',
	'williamboman/nvim-lsp-installer',
	'folke/neodev.nvim',
	"voldikss/vim-floaterm",
}
