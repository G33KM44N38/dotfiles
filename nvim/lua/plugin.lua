local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
	{
		"williamboman/mason.nvim",
		build = ":MasonUpdate"
	},
	{
		'VonHeikemen/lsp-zero.nvim',
		branch = 'v2.x',
		dependencies = {
			-- LSP Support
			{ 'neovim/nvim-lspconfig' }, -- Required
			{
				-- Optional
				'williamboman/mason.nvim',
				build = function()
					pcall(vim.cmd, 'MasonUpdate')
				end,
			},
			{ 'williamboman/mason-lspconfig.nvim' }, -- Optional

			-- Autocompletion
			{ 'hrsh7th/nvim-cmp' }, -- Required
			{ 'hrsh7th/cmp-nvim-lsp' }, -- Required
			{ 'L3MON4D3/LuaSnip' }, -- Required
		}
	},
	'andrewstuart/vim-kubernetes',
	"kabouzeid/nvim-lspinstall",
	event = "VimEnter",
	config = function()
		require("plugins.lspinstall")
	end,
	'prabirshrestha/vim-lsp',
	-- 'kshenoy/vim-signature',
	'preservim/vimux',
	'vim-test/vim-test',
	{
		'junegunn/fzf',
		build = function() vim.fn['fzf#install']() end
	},
	'junegunn/fzf.vim',
	'joaohkfaria/vim-jest-snippets',
	'ryanoasis/vim-devicons',
	{
		'fatih/vim-go',
		build = ':GoUpdateBinaries'
	},
	'kdheepak/lazygit.nvim',
	'preservim/nerdtree',
	-- 'pangloss/vim-javascript',
	-- 'leafgarland/typescript-vim',
	-- 'peitalin/vim-jsx-typescript',
	{
		'styled-components/vim-styled-components',
		branch = 'main'
	},
	'jparise/vim-graphql',
	'ThePrimeagen/harpoon',
	'ThePrimeagen/vim-be-good',
	{
		'ldelossa/gh.nvim',
		dependencies = {
			{ 'ldelossa/litee.nvim' }
		}
	},
	{ "RRethy/vim-illuminate" },
	{
		"jose-elias-alvarez/null-ls.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
	},
	-- { 'anuvyklack/hydra.nvim',
	-- 	dependencies = 'anuvyklack/keymap-layer.nvim'
	-- },
	{ 'lukas-reineke/indent-blankline.nvim' },
	-- { 'epilande/vim-react-snippets' },
	{ 'windwp/nvim-autopairs' },
	{ 'windwp/nvim-ts-autotag' },
	{ 'norcalli/nvim-colorizer.lua' },
	{ 'hoob3rt/lualine.nvim' },
	{ 'kyazdani42/nvim-web-devicons' },
	{ 'akinsho/bufferline.nvim' },
	{
		'akinsho/toggleterm.nvim',
		version = "*",
		config = function() require("toggleterm").setup() end
	},
	{ 'ray-x/go.nvim' },
	{ 'ray-x/guihua.lua' },
	{
		"glepnir/lspsaga.nvim",
		branch = "main",
		config = function()
			require('lspsaga').setup({})
		end,
	},
	{ 'yamatsum/nvim-cursorline' },
	'airblade/vim-gitgutter',
	'RishabhRD/popfix',
	'RishabhRD/nvim-cheat.sh',
	'folke/lsp-colors.nvim',
	'L3MON4D3/LuaSnip',
	'SirVer/ultisnips',
	'cdelledonne/vim-cmake',
	'christianchiarulli/nvcode-color-schemes.vim',
	'dcampos/cmp-snippy',
	'dcampos/nvim-snippy',
	'f3fora/cmp-spell',
	'honza/vim-snippets',
	'hrsh7th/cmp-buffer',
	'hrsh7th/cmp-cmdline',
	'hrsh7th/cmp-nvim-lsp',
	'hrsh7th/cmp-nvim-lsp-document-symbol',
	'hrsh7th/cmp-nvim-lsp-signature-help',
	'hrsh7th/cmp-omni',
	'hrsh7th/cmp-path',
	'hrsh7th/nvim-cmp',
	'liuchengxu/vista.vim',
	'neovim/nvim-lspconfig',
	'nvim-lua/plenary.nvim',
	'nvim-telescope/telescope.nvim',
	'nvim-treesitter/playground',
	'onsails/lspkind-nvim',
	'preservim/tagbar',
	'quangnguyen30192/cmp-nvim-ultisnips',
	'rafi/awesome-vim-colorschemes',
	'ray-x/lsp_signature.nvim',
	'saadparwaiz1/cmp_luasnip',
	'shaunsingh/nord.nvim',
	'tc50cal/vim-terminal',
	'tpope/vim-commentary',
	'tarekbecker/vim-yaml-formatter',
	'tpope/vim-fugitive',
	'tpope/vim-surround',
	'williamboman/nvim-lsp-installer',
	'folke/trouble.nvim',
	'folke/neodev.nvim',
	'leoluz/nvim-dap-go',
	-- { 'theHamsta/nvim-dap-virtual-text' },
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap" }
	},
	{ "voldikss/vim-floaterm" },
	{ "LunarVim/Colorschemes" },
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

}

local opts = {}

require("lazy").setup(plugins, opts)
