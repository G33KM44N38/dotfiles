return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		local ok, telescope = pcall(require, "telescope")
		if not ok then
			return
		end
		local actions = require("telescope.actions")
		telescope.setup({
			picker = {},
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
				file_ignore_patterns = {
					"node_modules/",
					".git/",
					"dist/",
					"go.sum",
					"package-lock.json",
					"lazy-lock.json",
					"target",
					"Cargo.lock",
					".next/",
				},
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
			pickers = {
				-- You can also configure specific pickers to have different sorting behavior
				find_files = {
					-- For even more exact matching on find_files specifically
					sorter = require("telescope.sorters").get_substr_matcher,
				},
				live_grep = {
					-- Keep fuzzy for live_grep since it's useful for search
					sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
				},
			},
		})

		-- Note: You have duplicate "gi" mappings - the second one overwrites the first
		-- Fixed to use different keys:
		vim.api.nvim_set_keymap("n", "gI", "<cmd>Telescope lsp_implementations<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap("n", "gd", "<cmd>Telescope lsp_definitions<CR>", { noremap = true, silent = true })
		vim.api.nvim_set_keymap(
			"n",
			"<leader>hi",
			":lua require('telescope.builtin').find_files({ hidden = true, no_ignore = true, file_ignore_patterns = {'.git/'} })<CR>",
			{ noremap = true, silent = true }
		)
	end,
}
