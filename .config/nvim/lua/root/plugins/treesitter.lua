return {
	'nvim-treesitter/nvim-treesitter',
	config = function()
		-- Load nvim-treesitter and get the configs module
		local status_ok, configs = pcall(require, "nvim-treesitter.configs")
		if not status_ok then
			return
		end

		-- Ensure that the required parsers are installed
		require 'nvim-treesitter.install'.ensure_installed({
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
			"rust"
		})

		configs.setup {
			autopairs = {
				enable = true,
			},
			highlight = {
				enable = true,
				disable = { "" },
				filetype_exclude = { "tsx" },
				additional_vim_regex_highlighting = { "tsx" }
				-- additional_vim_regex_highlighting = true,
			},
			indent = {
				enable = true,
				disable = {
					-- "yaml"
				}
			},
			context_commentstring = {
				enable = true,
				enable_autocmd = false,
			},
		}
	end
}
