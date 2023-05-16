local lspconfig = require('lspconfig')
lspconfig.yamlls.setup({
	settings = {
		yaml = {
			keyOrdering = false
		}
	}
})
