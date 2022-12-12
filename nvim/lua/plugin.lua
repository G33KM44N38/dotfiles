local packer = require 'packer'

packer.init {
	{
		display = {
			non_interactive = false, -- If true, disable display windows for all operations
			open_fn         = nil, -- An optional function to open a window for packer's display
			open_cmd        = '65vnew \\[packer\\]', -- An optional command to open a window for packer's display
			working_sym     = '⟳', -- The symbol for a plugin being installed/updated
			error_sym       = '✗', -- The symbol for a plugin with an error in installation/updating
			done_sym        = '✓', -- The symbol for a plugin which has completed installation/updating
			removed_sym     = '-', -- The symbol for an unused plugin which was removed
			moved_sym       = '→', -- The symbol for a plugin which was moved (e.g. from opt to start)
			header_sym      = '━', -- The symbol for the header line in packer's display
			show_all_info   = true, -- Should packer show all update details automatically?
			prompt_border   = 'double', -- Border style of prompt popups.
		}
	}
}

local use = packer.use

packer.reset()
packer.startup(function()
	use { "RRethy/vim-illuminate" }
	use { "jose-elias-alvarez/null-ls.nvim", requires = { "nvim-lua/plenary.nvim" }, }
	use { 'nvim-treesitter/nvim-treesitter', run = ":TSUpdate" }
	use { 'anuvyklack/hydra.nvim', requires = 'anuvyklack/keymap-layer.nvim' }
	use { 'lukas-reineke/indent-blankline.nvim' }
	use { 'epilande/vim-react-snippets' }
	use { 'windwp/nvim-autopairs' }
	use { 'windwp/nvim-ts-autotag' }
	use { 'norcalli/nvim-colorizer.lua' }
	use { 'hoob3rt/lualine.nvim' }
	use { 'kyazdani42/nvim-web-devicons' }
	use { 'akinsho/bufferline.nvim' }
	use { 'akinsho/toggleterm.nvim', tag = 'v2.*', config = function() require("toggleterm").setup() end }
	use { 'ray-x/go.nvim' }
	use { 'ray-x/guihua.lua' }
	use { 'glepnir/lspsaga.nvim' }
	use { 'yamatsum/nvim-cursorline' }
	use 'airblade/vim-gitgutter'
	use 'RishabhRD/popfix'
	use 'RishabhRD/nvim-cheat.sh'
	use 'folke/lsp-colors.nvim'
	-- use 'kevinhwang91/rnvimr'
	use 'L3MON4D3/LuaSnip'
	use 'SirVer/ultisnips'
	-- use 'cdelledonne/vim-cmake'
	-- use 'chrisbra/Colorizer'
	use 'christianchiarulli/nvcode-color-schemes.vim'
	use 'dcampos/cmp-snippy'
	use 'dcampos/nvim-snippy'
	use 'f3fora/cmp-spell'
	use 'honza/vim-snippets'
	use 'hrsh7th/cmp-buffer'
	use 'hrsh7th/cmp-cmdline'
	use 'hrsh7th/cmp-nvim-lsp'
	use 'hrsh7th/cmp-nvim-lsp-document-symbol'
	use 'hrsh7th/cmp-nvim-lsp-signature-help'
	use 'hrsh7th/cmp-omni'
	use 'hrsh7th/cmp-path'
	use 'hrsh7th/nvim-cmp'
	use 'liuchengxu/vista.vim'
	use 'neovim/nvim-lspconfig'
	use 'nvim-lua/plenary.nvim'
	use 'nvim-telescope/telescope.nvim'
	use 'nvim-treesitter/playground'
	use 'onsails/lspkind-nvim'
	use 'preservim/tagbar'
	use 'quangnguyen30192/cmp-nvim-ultisnips'
	use 'rafi/awesome-vim-colorschemes'
	use 'ray-x/lsp_signature.nvim'
	use 'ryanoasis/vim-devicons'
	use 'saadparwaiz1/cmp_luasnip'
	use 'shaunsingh/nord.nvim'
	use 'sunjon/shade.nvim'
	use 'tc50cal/vim-terminal'
	use 'tpope/vim-commentary'
	use 'tpope/vim-fugitive'
	use 'tpope/vim-surround'
	use 'williamboman/nvim-lsp-installer'
	use { 'wbthomason/packer.nvim', opt = false }
	use 'folke/trouble.nvim'
	use { 'theHamsta/nvim-dap-virtual-text' }
	use { 'mfussenegger/nvim-dap' }
	use { "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } }
	use 'leoluz/nvim-dap-go'
end)
