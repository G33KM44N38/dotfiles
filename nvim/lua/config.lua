local success, plugin = pcall(require, 'plugin')

if success then
  require('autopair_rc')
  require('autotag_rc')
  require('base')
  require('buffer_line_rc')
  require('colorizer_rc')
  require('go_rc')
  require('hydra_rc')
  require('keymap')
  require('lsp')
  require('lspsaga_rc')
  require('rc_cmp')
  require('status_line_rc')
  require('telescope')
  require('ter_init')
  require('virtual_type_rc')
  require('cursor_line_rc')
  require('ultisnip_rc')
  require('option')
else
  print('Erreur lors du chargement du plugin:', plugin)
end

