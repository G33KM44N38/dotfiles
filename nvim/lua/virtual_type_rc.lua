local status, virtual = pcall(require, 'virtualtypes')
if (not status)then return end

require'nvim_lsp'.lspconfig.setup{on_attach=require'virtualtypes'.on_attach}
