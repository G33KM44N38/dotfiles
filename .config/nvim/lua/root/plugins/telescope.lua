return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		{ 'nvim-telescope/telescope-fzf-native.nvim', build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release' }
	},

	config = function()
		local ok, telescope = pcall(require, "telescope")

		if not ok then
			return
		end

		local actions = require("telescope.actions")

		telescope.setup {
			extensions = {
				fzf = {
				}
			},
			picker = {
			},
			defaults = {
				vimgrep_arguments = {
					"rg",
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--no-ignore",
					"--smart-case",
					"--hidden",
				},

				prompt_prefix = "",
				selection_caret = "  ",
				entry_prefix = "  ",
				initial_mode = "insert",
				selection_strategy = "reset",
				sorting_strategy = "descending",
				layout_strategy = "horizontal",
				layout_config = {
					horizontal = {
						prompt_position = "bottom",
						preview_width = 0.55,
						results_width = 0.8,
					},
					vertical = {
						mirror = false,
					},
					width = 0.80,
					height = 0.85,
					preview_cutoff = 120,
				},
				file_sorter = require("telescope.sorters").get_fuzzy_file,
				file_ignore_patterns = { "node_modules/", ".git/", "dist/", "go.sum", "package-lock.json", "lazy-lock.json", "target", "Cargo.lock", ".next/" },
				generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
				path_display = { "absolute" },
				winblend = 0,
				color_devicons = true,
				use_less = true,
				set_env = { ["COLORTERM"] = "truecolor" },
				file_previewer = require("telescope.previewers").vim_buffer_cat.new,
				grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
				qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
				buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
				mappings = {
					i = {
						["<C-j>"] = "move_selection_next",
						["<C-k>"] = "move_selection_previous",
					},
					n = {
						["<C-j>"] = "move_selection_next",
						["<C-k>"] = "move_selection_previous",
					},
				},
			},
		}

		-- To get fzf loaded and working with telescope, you need to call
		-- load_extension, somewhere after setup function:
		require('telescope').load_extension('fzf')
		-- require "plugins.custom.telescope.multigrep".setup()
	end
}
