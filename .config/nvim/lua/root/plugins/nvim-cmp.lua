return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"hrsh7th/cmp-cmdline",
		"petertriho/cmp-git",
		"hrsh7th/cmp-buffer",   -- source for text in buffer
		"hrsh7th/cmp-path",     -- source for file system paths
		"L3MON4D3/LuaSnip",     -- snippet engine
		"saadparwaiz1/cmp_luasnip", -- for autocompletion
		"rafamadriz/friendly-snippets", -- useful snippets
		"onsails/lspkind.nvim", -- vs-code like pictograms
	},
	config = function()
		local cmp = require("cmp")
		local luasnip = require("luasnip")
		local lspkind = require("lspkind")
		local cmp_luasnip = require("cmp_luasnip")
		require("luasnip.loaders.from_vscode").lazy_load()

		cmp.setup.cmdline({ '/', '?' }, {
			mapping = cmp.mapping.preset.cmdline({
				['<C-y>'] = cmp.mapping(function(fallback)
					local entry = cmp.get_selected_entry()
					cmp.confirm(entry)
				end, { "i", "s" })
			}),
			sources = {
				{ name = 'buffer' }
			}
		})

		cmp.setup.cmdline(":", {
			mapping = cmp.mapping.preset.cmdline({
				['<C-y>'] = cmp.mapping(function(fallback)
					local entry = cmp.get_selected_entry()
					cmp.confirm(entry)
				end, { "i", "s" })
			}),
			sources = {
				{ name = "path" },
				{ name = "cmdline" },
			},
		})
		cmp.setup({
			preselect = cmp.PreselectMode.None,
			completion = {
				completeopt = "menu,preview",
			},
			snippet = {
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			mapping = {
				['<c-j>'] = cmp.mapping(function()
					if cmp.visible() then
						cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
					end
				end, { 'i', 's', 'c' }),
				['<c-k>'] = cmp.mapping(function()
					if cmp.visible() then
						cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
					end
				end, { 'i', 's', 'c' }),
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = true, behavior = cmp.SelectBehavior.Select }),
				["<Tab>"] = cmp.mapping(function()
					if cmp.visible() then
						cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
					end
				end, { "i", "s", "c" }),
				["<S-Tab>"] = cmp.mapping(function()
					if cmp.visible() then
						cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
					end
				end, { "i", "s", "c" }),
			},
			sources = cmp.config.sources({
				{ name = "nvim_lsp" }, -- LSP source (assurez-vous que le serveur Lua est bien configuré)
				{ name = "luasnip", group_index = 1 }, -- Snippets
				{ name = "buffer" },   -- Texte dans le buffer actuel
				{ name = "path" },     -- Chemins de fichiers
			}),
			formatting = {
				fields = { "abbr" },
				expandable_indicator = false,
				format = lspkind.cmp_format({
					maxwidth = 50,
					ellipsis_char = "...",
				}),
			},
		})
	end,
}
