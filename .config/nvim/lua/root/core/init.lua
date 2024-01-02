require("root.core.keymap")
-- Required to be compatible with Neovim
vim.opt.compatible = false

-- Set fill characters for statusline
vim.opt.fillchars:append({ stl = ' ', stlnc = ' ' })

-- Set fold method to 'indent'
vim.opt.foldmethod = 'indent'

-- Set the fold level to 99
vim.opt.foldlevel = 99

-- Set the encoding to UTF-8
vim.opt.encoding = 'utf-8'

-- Enable unnamed clipboard
vim.opt.clipboard = 'unnamed'

-- Show matching brackets
vim.opt.showmatch = true

-- Add FZF to the runtime path
-- vim.opt.rtp:append('/usr/local/opt/fzf')

-- Show relative line numbers
vim.opt.rnu = true
vim.opt.nu = true

-- Enable the mouse in all modes
vim.opt.mouse = 'a'

-- Show line numbers
vim.opt.number = true

-- Automatically reload files that have been changed outside of Vim
vim.opt.autoread = true

-- Set the backspace behavior
vim.opt.backspace = { 'indent', 'eol', 'start' }

-- set the syntax on
vim.cmd("autocmd FileType go syntax enable")


-- Transparent background
vim.cmd('hi Normal guibg=NONE ctermbg=NONE')

-- Set tabstops for filetypes
vim.cmd("autocmd Filetype * setlocal ts=5 sw=5")

-- Run LSP format on buffer write post
-- vim.cmd('silent! autocmd BufWritePost * lua vim.lsp.buf.format()')

vim.g.ft_man_open_mode = 'vert'
vim.g.cmake_link_compile_commands = 1
vim.g.rnvimr_ex_enable = 1
vim.g.netrw_liststyle = 3
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 20

-- Airline_Vim
vim.g.airline_powerline_fonts = 1
if not vim.g.airline_symbols then
	vim.g.airline_symbols = {}
end

-- Custom indentPlugin Show
vim.g.indent_guides_enable_on_vim_startup = 1
vim.g.indent_guides_auto_colors = 0
vim.g.indent_guides_start_level = 2
vim.g.indent_guides_guide_size = 1
vim.cmd('highlight IndentGuidesOdd ctermbg=238')
vim.cmd('highlight IndentGuidesEven ctermbg=242')
vim.cmd('highlight Error NONE')
vim.cmd('highlight ErrorMsg NONE')

-- Disable function highlighting (affects both C and C++ files)
vim.g.cpp_function_highlight = 1

-- Enable highlighting of C++11 attributes
vim.g.cpp_attributes_highlight = 1

-- Highlight struct/class member variables (affects both C and C++ files)
vim.g.cpp_member_highlight = 1

-- vim-test
vim.cmd('let test#strategy = "vimux"')

-- set completeopt=noinsert,menuone,noselect
vim.g.completion_matching_strategy_list = { 'exact', 'substring', 'fuzzy', 'all' }

-- configure nvcode-color-schemes
vim.g.nvcode_termcolors = 256


vim.cmd("set nowrap")
vim.api.nvim_set_option('autoindent', false)
vim.api.nvim_set_option('wrap', false)
vim.api.nvim_set_option('autoindent', false)
vim.api.nvim_set_option('wrap', false)
