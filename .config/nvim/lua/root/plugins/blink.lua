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
			["<C-Space>"] = { "show", "fallback" },
		},
		sources = {
			default = { "snippets", "lsp", "path", "buffer", "emoji", "conventional_commits", "wikilinks_inline", "wikilinks" },
			providers = {
				snippets = {
					name = "Snippets",
					score_offset = 300,
					min_keyword_length = 1,
				},
				lsp = {
					name = "LSP",
					score_offset = 50,
					min_keyword_length = 0,
				},
				buffer = {
					name = "Buffer",
					score_offset = -50,
					min_keyword_length = 1,
					max_items = 5,
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
				wikilinks = {
					name = "Wiki Links",
					module = "root.blink-wikilinks",
					score_offset = 80,
					min_keyword_length = 0,
					max_items = 15,
					opts = {
						workspace_path = "/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/",
					},
					should_show_items = function()
						if vim.bo.filetype ~= "markdown" then
							return false
						end
						local line = vim.api.nvim_get_current_line()
						local col = vim.api.nvim_win_get_cursor(0)[2]
						local line_to_cursor = line:sub(1, col + 1)
						return line_to_cursor:find("%[%[[^%]]*$") ~= nil
					end,
				},
			wikilinks_inline = {
				name = "Wiki Links Inline",
				module = "root.blink-wikilinks-inline",
				score_offset = 85,
				min_keyword_length = 2,
				max_items = 15,
				opts = {
					workspace_path = "/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain/",
				},
				-- Only check if we're inside [[ ]] brackets - source:enabled() handles filetype
				should_show_items = function()
					local line = vim.api.nvim_get_current_line()
					local col = vim.api.nvim_win_get_cursor(0)[2]
					local line_to_cursor = line:sub(1, col + 1)
					return line_to_cursor:find("%[%[[^%]]*$") == nil
				end,
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
