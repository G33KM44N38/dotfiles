local success, plugin = pcall(require, 'plugin')

if success then
	require('status_line_rc')
	require('lspconfig')
	require('option')
	require('keymap')
	require('autopair_rc')
	require('autotag_rc')
	require('base')
	require('buffer_line_rc')
	require('lsp')
	require('rc_cmp')
	require('status_line_rc')
	require('telescope')
	require('ter_init')
	require('ultisnip_rc')
	require("rc_treesitter")
	require('dap-go').setup()
	require("dapui").setup()
	require("rc_copilot")
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
