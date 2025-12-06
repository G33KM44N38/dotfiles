return {
	{
		"f-person/git-blame.nvim",
		-- load the plugin at startup
		event = "VeryLazy",
		-- Because of the keys part, you will be lazy loading this plugin.
		-- The plugin will only load once one of the keys is used.
		-- If you want to load the plugin at startup, add something like event = "VeryLazy",
		-- or lazy = false. One of both options will work.
		opts = {
			-- your configuration comes here
			-- for example
			enabled = false, -- if you want to enable the plugin
			message_template = "<author> •  <summary> • <date> • <<sha>>", -- template for the blame message, check the Message template section for more options
			date_format = "%m-%d-%Y %H:%M:%S", -- template for the date, check Date format section for more options
			virtual_text_column = 1, -- virtual text start column, check Start virtual text at column section for more options
		},
	},
	{
		"echasnovski/mini.indentscope",
		version = false,
		config = function()
			require("mini.indentscope").setup()
		end,
	},
	{
		"windwp/nvim-ts-autotag",
		opts = {},
	},
	"ThePrimeagen/refactoring.nvim",
	"nvim-lua/plenary.nvim",
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
	"nvim-treesitter/nvim-treesitter-context",
	{
		"fatih/vim-go",
		keys = false,
		build = ":GoUpdateBinaries",
		config = function()
			vim.g.go_def_mapping_enabled = 0
			vim.g.go_doc_keywordprg_enabled = 0
		end,
	},
}
