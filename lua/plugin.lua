local packer = require 'packer'

packer.init{
{
  display = {
    non_interactive = false, -- If true, disable display windows for all operations
    open_fn  = nil, -- An optional function to open a window for packer's display
    open_cmd = '65vnew \\[packer\\]', -- An optional command to open a window for packer's display
    working_sym = '⟳', -- The symbol for a plugin being installed/updated
    error_sym = '✗', -- The symbol for a plugin with an error in installation/updating
    done_sym = '✓', -- The symbol for a plugin which has completed installation/updating
    removed_sym = '-', -- The symbol for an unused plugin which was removed
    moved_sym = '→', -- The symbol for a plugin which was moved (e.g. from opt to start)
    header_sym = '━', -- The symbol for the header line in packer's display
    show_all_info = true, -- Should packer show all update details automatically?
    prompt_border = 'double', -- Border style of prompt popups.
    }
  }
}

local use = packer.use

packer.reset()

packer.startup(function()
	use 'nvim-telescope/telescope.nvim'
	use {'nvim-lua/plenary.nvim'}
	use { 'nvim-treesitter/nvim-treesitter', run = ":TSUpdate"}
	use 'hrsh7th/cmp-buffer'
	use 'dcampos/cmp-snippy'
	use 'quangnguyen30192/cmp-nvim-ultisnips'
	use 'f3fora/cmp-spell'
	use 'hrsh7th/cmp-cmdline'
	use 'hrsh7th/cmp-nvim-lsp'
	use 'hrsh7th/cmp-nvim-lsp-document-symbol'
	use 'hrsh7th/cmp-nvim-lsp-signature-help'
	use 'hrsh7th/cmp-omni'
	use 'hrsh7th/cmp-path'
	use 'saadparwaiz1/cmp_luasnip'
	use 'hrsh7th/nvim-cmp'
	use 'tpope/vim-commentary'
end)
