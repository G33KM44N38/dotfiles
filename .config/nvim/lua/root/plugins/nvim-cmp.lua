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
			mapping = cmp.mapping.preset.insert({
				["<C-k>"] = cmp.mapping.select_prev_item(),
				["<C-j>"] = cmp.mapping.select_next_item(),
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-y>"] = cmp.config.disable,
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = true }),
				["<Tab>"] = cmp.mapping(function(fallback)
					luasnip.jump(1)
				end, { "i", "s", "c" }),
				["<S-Tab>"] = cmp.mapping(function(fallback)
					luasnip.jump(-1)
				end, { "i", "s", "c" }),
			}),
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

		-- Configuration pour les commandes `/` et `?`
		cmp.setup.cmdline({ '/', '?' }, {
			mapping = {
				['<CR>'] = cmp.mapping.confirm({ select = true }),
				['<Tab>'] = cmp.mapping(cmp.mapping({
					i = function(fallback)
						if cmp.visible() and cmp.get_active_entry() then
							cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
						else
							fallback()
						end
					end,
					s = cmp.mapping.confirm({ select = true }),
					c = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
				})),
				['<C-k>'] = cmp.mapping.select_prev_item({ 'i', 'c' }),
				['<C-j>'] = cmp.mapping.select_next_item({ 'i', 'c' }),
			},
			sources = {
				{ name = 'buffer' }
			}
		})

		-- Configuration pour la commande `:`
		cmp.setup.cmdline(":", {
			mapping = {
				['<CR>'] = cmp.mapping.confirm({ select = true }),
				['<Tab>'] = cmp.mapping(function(fallback)
					if cmp.visible() and cmp.get_active_entry() then
						cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
					else
						fallback()
					end
				end, { "i", "s", "c" }),
				['<C-k>'] = cmp.mapping.select_prev_item({ 'i', 'c' }),
				['<C-j>'] = cmp.mapping.select_next_item({ 'i', 'c' }),
			},
			sources = {
				{ name = "path" },
				{ name = "cmdline" },
			},
		})
	end,
}
