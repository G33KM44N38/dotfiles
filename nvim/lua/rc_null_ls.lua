local null_ls = require('null-ls')

local formatting = null_ls.builtins.formatting

local sources = {
	formatting.stylua,
	formatting.fish,
}

null_ls.setup({
	sources = sources
})
