return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		'SirVer/ultisnips',
		"quangnguyen30192/cmp-nvim-ultisnips",
		-- "zbirenbaum/copilot-cmp",
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
		local cmp_ultisnips_mappings = require("cmp_nvim_ultisnips.mappings")
		require("luasnip.loaders.from_vscode").lazy_load()


		cmp.setup({
			-- preselect = cmp.PreselectMode.Item, -- set focus on the first line
			preselect = cmp.PreselectMode.None,
			completion = {
				completeopt = "menu,preview",
			},
			snippet = { -- configure how nvim-cmp interacts with snippet engine
				expand = function(args)
					luasnip.lsp_expand(args.body)
					-- vim.fn["UltiSnips#Anon"](args.body)
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-k>"] = cmp.mapping.select_prev_item(), -- previous suggestion
				["<C-j>"] = cmp.mapping.select_next_item(), -- next suggestion
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-e>"] = cmp.mapping.abort(), -- close completion window
				["<C-y>"] = {},  --disable for copilot
				["<CR>"] = cmp.mapping.confirm({ select = true }),
				["<Tab>"] = cmp.mapping(
					function(fallback)
						luasnip.jump(1)
						cmp_ultisnips_mappings.expand_or_jump_forwards(fallback)
					end,
					{ "i", "s", "c" }
				),
				["<S-Tab>"] = cmp.mapping(
					function(fallback)
						luasnip.jump(-1)
						cmp_ultisnips_mappings.jump_backwards(fallback)
					end,
					{ "i", "s", "c" }
				),
			}),
			sources = cmp.config.sources({
				-- { name = "copilot" },
				{ name = "ultisnips", group_index = 1 },
				{ name = "luasnip",   group_index = 1 }, -- snippets
				{ name = "nvim_lsp" },
				{ name = "buffer" },   -- text within current buffer
				{ name = "path" },     -- file system paths
			}),
			-- configure lspkind for vs-code like pictograms in completion menu
			formatting = {
				format = lspkind.cmp_format({
					maxwidth = 50,
					ellipsis_char = "...",
				}),
			},
		})

		-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
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
				['<C-k>'] = cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 'c' }),
				['<C-j>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
			},
			sources = {
				{ name = 'buffer' }
			}
		})

		cmp.setup.cmdline(":", {
			mapping = {
				['<CR>'] = cmp.mapping.confirm({ select = true }),
				-- ['<Up>'] = cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 'c' }),
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
				['<C-k>'] = cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 'c' }),
				['<C-j>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
			},
			sources = {
				{ name = "path" },
				{ name = "cmdline" },
			},
		})
	end,
}
