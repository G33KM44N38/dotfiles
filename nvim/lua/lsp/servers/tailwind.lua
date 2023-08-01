local M = {}

M.setup = function(on_attach, capabilities)
  local lspconfig = require('lspconfig')
  local configs = require('lspconfig/configs')

  if not lspconfig.tailwindcss then
    configs.tailwindcss = {
      default_config = {
        cmd = { 'tailwindcss-language-server', '--stdio' },
        filetypes = { 'html', 'css', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
        root_dir = lspconfig.util.root_pattern('tailwind.config.js', 'postcss.config.js'),
        settings = {},
      },
    }
  end

  lspconfig.tailwindcss.setup{
    on_attach = on_attach,
    capabilities = capabilities,
  }
end

return M
