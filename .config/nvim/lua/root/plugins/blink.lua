return {
	'saghen/blink.cmp',
	version = '1.*',
	dependencies = {
		'L3MON4D3/LuaSnip',
		'rafamadriz/friendly-snippets',
		"moyiz/blink-emoji.nvim",

		{ 'disrupted/blink-cmp-conventional-commits' },
	},
	opts = {
		cmdline = {
			keymap = {
				preset    = 'none',
				['<C-j>'] = { 'select_next', 'fallback' },
				['<C-k>'] = { 'select_prev', 'fallback' },
				['<Tab>'] = { 'accept' },

			},
			completion = { menu = { auto_show = true } },
		},
		keymap = {
			preset      = 'none',
			['<C-j>']   = { 'select_next' },
			['<C-k>']   = { 'select_prev' },
			['<CR>']    = { 'accept', 'fallback' },
			['<Tab>']   = { 'select_next', 'fallback' },
			['<S-Tab>'] = { 'select_prev', 'fallback' },
			['<C-b>']   = { 'scroll_documentation_up' },
			['<C-f>']   = { 'scroll_documentation_down' },
			['<C-e>']   = { 'hide' },
		},
		sources = {
			default = { 'conventional_commits', 'lsp', 'path', 'snippets', 'buffer', "emoji" },
			providers = {
				emoji = {
					module = "blink-emoji",
					name = "Emoji",
					score_offset = 15, -- Tune by preference
					opts = { insert = true }, -- Insert emoji (default) or complete its name
					should_show_items = function()
						return vim.tbl_contains(
						-- Enable emoji completion only for git commits and markdown.
						-- By default, enabled for all file-types.
							{ "gitcommit", "markdown" },
							vim.o.filetype
						)
					end,
				},
				conventional_commits = {
					name = 'Conventional Commits',
					module = 'blink-cmp-conventional-commits',
					enabled = function()
						return vim.bo.filetype == 'gitcommit'
					end,
					---@module 'blink-cmp-conventional-commits'
					---@type blink-cmp-conventional-commits.Options
					opts = {}, -- none so far
				},
			}
		},
		snippets = { preset = 'luasnip' },

		appearance = {
			nerd_font_variant = 'mono',
		},
		-- (Default) Only show the documentation popup when manually triggered
		completion = { documentation = { auto_show = true } },
		fuzzy = {
			implementation = "prefer_rust_with_warning",
		},
	},
	opts_extend = { "sources.default" }
}
