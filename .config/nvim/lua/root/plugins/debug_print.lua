return {
	"andrewferrier/debugprint.nvim",

	opts = {
		keymaps = {
			normal = {
				plain_below = "g?p",
				plain_above = "g?P",
				variable_below = "g?v",
				variable_above = "g?V",
				variable_below_alwaysprompt = "",
				variable_above_alwaysprompt = "",
				surround_plain = "g?sp",
				surround_variable = "g?sv",
				surround_variable_alwaysprompt = "",
				textobj_below = "g?o",
				textobj_above = "g?O",
				textobj_surround = "g?so",
				toggle_comment_debug_prints = "",
				delete_debug_prints = "",
			},
			insert = {
				plain = "<C-G>p",
				variable = "<C-G>v",
			},
			visual = {
				variable_below = "g?v",
				variable_above = "g?V",
			},
		},
		-- … Other options
	},

	config = function(_, opts)
		require("debugprint").setup(opts)
		-- Load the modular debug_print system
		require("root.plugins.debug_print")
	end,

	dependencies = {
		"echasnovski/mini.nvim",
		"echasnovski/mini.hipatterns",
		"ibhagwan/fzf-lua",
		"nvim-telescope/telescope.nvim",
		"folke/snacks.nvim",
	},

	lazy = false,
	version = "*",
}
