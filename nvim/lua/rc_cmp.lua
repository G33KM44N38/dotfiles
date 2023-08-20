local ok, cmp = pcall(require, "cmp")
local lspkind = require('lspkind')

if not ok then
	return
end
local snip_status_ok, luasnip = pcall(require, "luasnip")
if not snip_status_ok then
	return
end

local cmp_ultisnips_mappings = require("cmp_nvim_ultisnips.mappings")

local icons = {
	Text = "",
	Method = "",
	Function = "",
	Constructor = "⌘",
	Field = "ﰠ",
	Variable = "",
	Class = "ﴯ",
	Interface = "",
	Module = "",
	Property = "ﰠ",
	Unit = "塞",
	Value = "",
	Enum = "",
	Keyword = "廓",
	Snippet = "",
	Color = "",
	File = "",
	Reference = "",
	Folder = "",
	EnumMember = "",
	Constant = "",
	Struct = "פּ",
	Event = "",
	Operator = "",
	TypeParameter = "",
}

cmp.setup {
	experimental = {
		native_menu = false,
		ghost_text = false,
	},
	confirmation = {
		get_commit_characters = function()
			return {}
		end,
	},
	completion = {
		completeopt = "menu,menuone,noinsert",
		keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],
		keyword_length = 1,
	},
	formatting = {
		format = lspkind.cmp_format({
			mode = "text_symbol",
			max_width = 50,
			ellipsis_char = '...',
			symbol_map = {
				Copilot = "",
				Method = "",
				Function = "",
				Constructor = "⌘",
				Field = "ﰠ",
				Variable = "",
				Class = "ﴯ",
				Interface = "",
				Module = "",
				Property = "ﰠ",
				Unit = "塞",
				Value = "",
				Enum = "",
				Keyword = "廓",
				Snippet = "",
				Color = "",
				File = "",
				Reference = "",
				Folder = "",
				EnumMember = "",
				Constant = "",
				Struct = "פּ",
				Event = "",
				Operator = "",
				Text = "",
				TypeParameter = "",
			}
		})
	},
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body) -- For `luasnip` users.
		end,
	},
	mapping = {
		["<C-k>"] = cmp.mapping.select_prev_item(),
		["<C-j>"] = cmp.mapping.select_next_item(),
		["<C-p>"] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
		-- ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),
		["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
		["<C-y>"] = cmp.config.disable, -- Specify `cmp.config.disable` if you want to remove the default `<C-y>` mapping.
		["<C-e>"] = cmp.mapping {
			i = cmp.mapping.abort(),
			c = cmp.mapping.close(),
		},
		-- Accept currently selected item. If none selected, `select` first item.
		-- Set `select` to `false` to only confirm explicitly selected items.
		["<CR>"] = cmp.mapping.confirm { select = true },
		["<C-n>"] = cmp.mapping(
			function(fallback)
				cmp_ultisnips_mappings.expand_or_jump_forwards(fallback)
			end,
			{ "i", "s", }
		),
	},
	sources = {
		{ name = 'copilot' },
		{ name = 'tailwindcss-colorizer-cmp' },
		{ name = 'ultisnips' },
		{ name = "nvim_lsp" },
		{ name = "nvim_lua" },
		{ name = "vsnip" },
		{ name = "path" },
		{ name = "buffer" },
		{ name = "nvim_lsp_signature_help" },
		{ name = 'nvim_lspEmmets_document_symbol' },
	},
	preselect = cmp.PreselectMode.None,
}

cmp.setup.cmdline("/", {
	mapping = {
		['<CR>'] = cmp.mapping.confirm({ select = true }),
		['<Up>'] = cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 'c' }),
		['<Down>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
		['<Tab>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
		['<C-k>'] = cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 'c' }),
		['<C-j>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
	},
	sources = {
		{ name = "buffer" },
	},
})

cmp.setup.cmdline(":", {
	mapping = {
		['<CR>'] = cmp.mapping.confirm({ select = true }),
		['<Up>'] = cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 'c' }),
		['<Tab>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
		['<Down>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
		['<C-k>'] = cmp.mapping(cmp.mapping.select_prev_item(), { 'i', 'c' }),
		['<C-j>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 'c' }),
	},
	sources = {
		{ name = "path" },
		{ name = "cmdline" },
	},
})
