return {
	"nvim-treesitter/nvim-treesitter",
	config = function()
		-- Load nvim-treesitter and get the configs module
		local status_ok, configs = pcall(require, "nvim-treesitter.configs")
		if not status_ok then
			return
		end

		-- Ensure that the required parsers are installed
		require("nvim-treesitter.install").ensure_installed({
			"go",
			"lua",
			"python",
			"typescript",
			"tsx",
			"javascript",
			"html",
			"css",
			"yaml",
			"json",
			"markdown",
			"markdown_inline",
			"cmake",
			"c",
			"bash",
			"prisma",
			"rust",
			"query",
		})
	end,
	otps = {
		autopairs = {
			enable = true,
		},
		highlight = {
				enable = true,
				disable = { "" },
				-- Performance optimization for large files (especially TSX with SVG)
				-- Treesitter is now fast enough for most cases, but we disable for very large files
				disable = function(lang, bufnr)
					if lang ~= "tsx" then
						return false
					end
					local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(bufnr))
					local file_size = ok and stats and stats.size or 0
					return file_size > 200000 -- Disable for files > 200KB
				end,
				-- Sync highlighting from start for better performance
				sync_from_start = true,
			},
		indent = {
			enable = true,
			disable = {
				-- "yaml"
			},
		},
		context_commentstring = {
			enable = true,
			enable_autocmd = false,
		},
		playground = {
			enable = true, -- Enable the playground
			updatetime = 25, -- Debounced time for highlighting nodes (in ms)
			persist_queries = false, -- Whether to save queries across sessions
			keybindings = {
				toggle_query_editor = "o",
				toggle_hl_groups = "i",
				toggle_injected_languages = "t",
				toggle_anonymous_nodes = "a",
				toggle_language_display = "I",
				focus_language = "f",
				unfocus_language = "F",
				update = "R",
				goto_node = "<cr>",
				show_help = "?",
			},
		},
	},
}
