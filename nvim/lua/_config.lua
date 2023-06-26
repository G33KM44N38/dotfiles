local success, plugin = pcall(require, 'plugin')

if success then
	require('lspconfig')
	require('option')
	require('keymap')
	require('autopair_rc')
	require('autotag_rc')
	require('base')
	require('buffer_line_rc')
	require('colorizer_rc')
	require('lsp')
	require('lspsaga_rc')
	require('rc_cmp')
	require('status_line_rc')
	require('telescope')
	require('ter_init')
	require('virtual_type_rc')
	require('cursor_line_rc')
	require('ultisnip_rc')
	require("rc_treesitter")
	require('dap-go').setup()
	require("dapui").setup()
	require("mason").setup({
		ui = {
			icons = {
				package_installed = "✓",
				package_pending = "➜",
				package_uninstalled = "✗"
			}
		}
	})
else
	print('Erreur lors du chargement du plugin:', plugin)
end
