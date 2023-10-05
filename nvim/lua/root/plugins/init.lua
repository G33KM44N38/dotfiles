return {
	{
		"zbirenbaum/copilot-cmp",
		config = function()
			require("copilot_cmp").setup()
		end
	},
	"kabouzeid/nvim-lspinstall",
	"onsails/lspkind.nvim",
	"zbirenbaum/copilot.lua",
	'nvim-lua/plenary.nvim',
	'preservim/vimux',
	'vim-test/vim-test',
	{
		'fatih/vim-go',
		build = ':GoUpdateBinaries'
	},
	'ThePrimeagen/harpoon',
	'ThePrimeagen/vim-be-good',
	{ 'windwp/nvim-autopairs' },
	{
		'windwp/nvim-ts-autotag',
		-- ft = { "jsx", "tsx" },
	},
	{ 'akinsho/bufferline.nvim' },
	{
		'akinsho/toggleterm.nvim',
		version = "*",
		config = function() require("toggleterm").setup() end
	},
	{
		"glepnir/lspsaga.nvim",
		branch = "main",
		config = function()
			require('lspsaga').setup({})
		end,
	},
	'folke/lsp-colors.nvim',
	'SirVer/ultisnips',
	'cdelledonne/vim-cmake',
	'dcampos/cmp-snippy',
	'dcampos/nvim-snippy',
	'hrsh7th/cmp-buffer',
	'hrsh7th/cmp-cmdline',
	'hrsh7th/cmp-nvim-lsp',
	'hrsh7th/cmp-nvim-lsp-document-symbol',
	'hrsh7th/cmp-nvim-lsp-signature-help',
	'hrsh7th/cmp-omni',
	'hrsh7th/cmp-path',
	'hrsh7th/nvim-cmp',
	'nvim-telescope/telescope.nvim',
	'preservim/tagbar',
	'quangnguyen30192/cmp-nvim-ultisnips',
	'rafi/awesome-vim-colorschemes',
	'ray-x/lsp_signature.nvim',
	'saadparwaiz1/cmp_luasnip',
	'tpope/vim-commentary',
	'tpope/vim-fugitive',
	'tpope/vim-surround',
	'williamboman/nvim-lsp-installer',
	'folke/neodev.nvim',
	'leoluz/nvim-dap-go',
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap" }
	},
	{ "voldikss/vim-floaterm" },
	{
		'lewis6991/gitsigns.nvim',
		config = function()
			require('gitsigns').setup()
		end
	},
	{
		'nvim-treesitter/nvim-treesitter',
		build = function()
			local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
			ts_update()
		end,
	},
	{
		"roobert/tailwindcss-colorizer-cmp.nvim",
		-- optionally, override the default options:
		build = function()
			require("tailwindcss-colorizer-cmp").setup({
				color_square_width = 2,
			})
		end

	}
}
