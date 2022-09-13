set nu
set autoindent
set relativenumber
syntax on
set ruler
set nowrap
nnoremap  <Leader>f :Files<CR>
nnoremap  <Leader>w :Rg<CR>
nnoremap  <Leader>pv :wincmd v<bar> :Ex <bar> :vertical resize 30<CR>
nnoremap  <Leader>t :vert terminal<CR>
imap  kj <Esc>
imap  KJ <Esc>
lua require('init')
