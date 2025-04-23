return {
	'saghen/blink.cmp',
	version = '1.*',
	dependencies = {
		'L3MON4D3/LuaSnip',
		'rafamadriz/friendly-snippets',
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
			['<C-j>']   = { 'select_next', 'fallback' },
			['<C-k>']   = { 'select_prev', 'fallback' },
			['<CR>']    = { 'accept' },
			['<Tab>']   = { 'select_next', 'fallback' },
			['<S-Tab>'] = { 'select_prev', 'fallback' },
			['<C-b>']   = { 'scroll_documentation_up' },
			['<C-f>']   = { 'scroll_documentation_down' },
			['<C-e>']   = { 'hide' },
		},
		sources = {
			default = { 'lsp', 'path', 'snippets', 'buffer' },
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
