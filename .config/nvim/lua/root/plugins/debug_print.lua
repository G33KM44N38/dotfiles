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
		local navigation = require("root.plugins.debug_print.navigation")
		local deletion = require("root.plugins.debug_print.deletion")
		local config_module = require("root.plugins.debug_print.config")

		-- Register keymaps
		vim.keymap.set("n", config_module.KEYMAPS.next_all, function()
			navigation.go_to_next_debug("all")
		end, { noremap = true, silent = true })

		vim.keymap.set("n", config_module.KEYMAPS.prev_all, function()
			navigation.go_to_prev_debug("all")
		end, { noremap = true, silent = true })

		vim.keymap.set("n", config_module.KEYMAPS.next_log, function()
			navigation.go_to_next_debug("log")
		end, { noremap = true, silent = true })

		vim.keymap.set("n", config_module.KEYMAPS.prev_log, function()
			navigation.go_to_prev_debug("log")
		end, { noremap = true, silent = true })

		vim.keymap.set("n", config_module.KEYMAPS.next_warn, function()
			navigation.go_to_next_debug("warn")
		end, { noremap = true, silent = true })

		vim.keymap.set("n", config_module.KEYMAPS.prev_warn, function()
			navigation.go_to_prev_debug("warn")
		end, { noremap = true, silent = true })

		vim.keymap.set("n", config_module.KEYMAPS.delete, function()
			deletion.delete_debug_at_cursor()
		end, { noremap = true, silent = true })

		-- Register commands
		vim.api.nvim_create_user_command(config_module.COMMANDS.next_log, function()
			navigation.go_to_next_debug("log")
		end, {})

		vim.api.nvim_create_user_command(config_module.COMMANDS.prev_log, function()
			navigation.go_to_prev_debug("log")
		end, {})

		vim.api.nvim_create_user_command(config_module.COMMANDS.next_warn, function()
			navigation.go_to_next_debug("warn")
		end, {})

		vim.api.nvim_create_user_command(config_module.COMMANDS.prev_warn, function()
			navigation.go_to_prev_debug("warn")
		end, {})

		vim.api.nvim_create_user_command(config_module.COMMANDS.next_all, function()
			navigation.go_to_next_debug("all")
		end, {})

		vim.api.nvim_create_user_command(config_module.COMMANDS.prev_all, function()
			navigation.go_to_prev_debug("all")
		end, {})
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
