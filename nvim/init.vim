" G33KM44N38 configs

set autoindent
set nowrap
nnoremap  <Space>f :Files<CR>
nnoremap  <Space>w :Rg<CR>
nnoremap  <Space>pv :NERDTree<CR>
nnoremap  <Space>"t :vert terminal<CR>
imap  kj <Esc>
imap  KJ <Esc>
imap  <Space><Space> <Esc>


set nocompatible              " required
set encoding=utf-8
set fillchars+=stl:\ ,stlnc:\
set foldmethod=indent
set foldlevel=99
set encoding=utf-8
set clipboard=unnamed
set showmatch
set rtp+=/usr/local/opt/fzf
set rnu
set mouse=a
set nu
set autoread
" syntax enable
" colorscheme waxcoin
colorscheme alduin
" colorscheme sonokai
" colorscheme sierra
" colorscheme orbital
" colorscheme Monokai
set backspace=indent,eol,start
set termguicolors
lua require('init')

" tansparent background
hi Normal guibg=NONE ctermbg=NONE

" au BufRead *.css, *.js, *.html, *.json :set tabstop=4
autocmd Filetype css setlocal ts=3 sw=3 expandtab
autocmd Filetype javascript setlocal ts=3 sw=3 expandtab
autocmd BufWritePre *.go :silent! lua require('go.format').gofmt()

"open vim in vertical
let g:ft_man_open_mode = 'vert'
let g:cmake_link_compile_commands = 1
let g:rnvimr_ex_enable = 1
let g:netrw_liststyle = 3
let g:netrw_banner = 0
let g:netrw_winsize = 20

"setting Neovim Tree
" let g:c_syntax_for_h = 1

call plug#begin()
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'joaohkfaria/vim-jest-snippets'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'ryanoasis/vim-devicons'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
Plug 'kdheepak/lazygit.nvim'
Plug 'preservim/nerdtree'
call plug#end()

" Airline_Vim
let g:airline_powerline_fonts = 1
if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif

" Custom indentPlugin Show
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_auto_colors = 0
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size = 1
hi IndentGuidesOdd  ctermbg=238
hi IndentGuidesEven ctermbg=242
hi Error NONE
hi ErrorMsg NONE

" Disable function highlighting (affects both C and C++ files)
let g:cpp_function_highlight = 1

" Enable highlighting of C++11 attributes
let g:cpp_attributes_highlight = 1

" Highlight struct/class member variables (affects both C and C++ files)
let g:cpp_member_highlight = 1

" configure treesitter
lua << EOF
require'nvim-treesitter.configs'.setup {
  ensure_installed = "all", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {
    enable = true,              -- false will disable the whole extension
    disable = { "rust" },  -- list of language that will be disabled
  },
}
EOF

"set completeopt=noinsert,menuone,noselect
let g:completion_matching_strategy_list = ['exact', 'substring', 'fuzzy', 'all']

" configure nvcode-color-schemes
let g:nvcode_termcolors=256

" checks if your terminal has 24-bit color support
if (has("termguicolors"))
    set termguicolors
    hi LineNr ctermbg=NONE guibg=NONE
endif
let g:vimspector_enable_mappings = 'HUMAN'
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsSnippetDirectories=["UltiSnips", "my_snip"]
let g:vista_icon_indent = ["╰─▸ ", "├─▸ "]
let g:vista_default_executive = 'ctags'
let g:vista_executive_for = {
  \ 'cpp': 'vim_lsp',
  \ 'php': 'vim_lsp',
  \ }
let g:vista_fzf_preview = ['right:50%']
