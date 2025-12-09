return {
	"saghen/blink.cmp",
	version = "1.*",
	dependencies = {
		"L3MON4D3/LuaSnip",
		"rafamadriz/friendly-snippets",
		"moyiz/blink-emoji.nvim",
		{ "disrupted/blink-cmp-conventional-commits" },
	},
	opts = {
		cmdline = {
			keymap = {
				preset = "none",
				["<C-j>"] = { "select_next", "fallback" },
				["<C-k>"] = { "select_prev", "fallback" },
				["<Tab>"] = { "accept" },
			},
			completion = { menu = { auto_show = true } },
		},
		keymap = {
			preset = "none",
			["<C-j>"] = { "select_next" },
			["<C-k>"] = { "select_prev" },
			["<CR>"] = { "accept", "fallback" },
			["<Tab>"] = { "select_next", "fallback" },
			["<S-Tab>"] = { "select_prev", "fallback" },
			["<C-b>"] = { "scroll_documentation_up" },
			["<C-f>"] = { "scroll_documentation_down" },
			["<C-e>"] = { "hide" },
			["<C-Space>"] = { "show", "fallback" }, -- ✅ Forcer manuellement
		},
		sources = {
			default = { "lsp", "path", "snippets", "buffer", "emoji", "conventional_commits" },
			providers = {
				lsp = {
					name = "LSP",
					score_offset = 100,
					min_keyword_length = 0, -- ✅ CHANGÉ: 1 → 0 (trigger immédiatement)
				},
				buffer = {
					name = "Buffer",
					score_offset = -50,
					min_keyword_length = 3,
					max_items = 5,
				},
				snippets = {
					name = "Snippets",
					score_offset = 50,
					min_keyword_length = 2,
				},
				path = {
					name = "Path",
					score_offset = 75,
					min_keyword_length = 1,
				},
				emoji = {
					module = "blink-emoji",
					name = "Emoji",
					score_offset = 15,
					opts = { insert = true },
					should_show_items = function()
						return vim.tbl_contains({ "gitcommit", "markdown" }, vim.o.filetype)
					end,
				},
				conventional_commits = {
					name = "Conventional Commits",
					module = "blink-cmp-conventional-commits",
					score_offset = 200,
					enabled = function()
						return vim.bo.filetype == "gitcommit"
					end,
					opts = {},
				},
			},
		},
		snippets = { preset = "luasnip" },
		appearance = {
			nerd_font_variant = "mono",
		},
		completion = {
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 100,
			},
			menu = {
				auto_show = true,
				draw = {
					columns = {
						{ "kind_icon" },
						{ "label", "label_description", gap = 1 },
						{ "source_name" },
					},
				},
			},
			-- ✅ AJOUTÉ: Configuration du trigger
			trigger = {
				show_on_insert_on_trigger_character = true,
			},
		},
		fuzzy = {
			implementation = "prefer_rust_with_warning",
			frecency = {
				enabled = true,
			},
			use_proximity = true,
		},
	},
	opts_extend = { "sources.default" },
}
