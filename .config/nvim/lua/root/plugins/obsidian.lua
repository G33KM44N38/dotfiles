return {
	"epwalsh/obsidian.nvim",
	version = "*",
	lazy = true,
	ft = "markdown",
	dependencies = {
		"nvim-lua/plenary.nvim",

	},
	opts = {
		["gd"] = {
			action = function()
				return require("obsidian").util.gf_passthrough()
			end,
			opts = { noremap = false, expr = true, buffer = true },
		},
		workspaces = {
			{
				name = "personal",
				path = "~/SecondBrain/Second_Brain/",
			}
		},

		completion = {
			nvim_cmp = true,
			min_chars = 2,
		},

		templates = {
			subdir =
			"_templates_/",
			date_format = "%Y-%m-%d",
			time_format = "%H:%M",
			substitutions = {},
		},
	},
	vim.api.nvim_set_keymap("n", "<leader>o", ":Obsidian", { noremap = true, silent = false })
}
