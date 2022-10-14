" Vim color file
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2001 Jul 23
" This is the default color scheme.  It doesn't define the Normal
" highlighting, it uses whatever the colors used to be.
" Set 'background' back to the default.  The value can't always be estimated
" and is then guessed.
hi clear Normal
set bg&
" Remove all existing highlighting and set the defaults.
hi clear

" Load the syntax highlighting defaults, if it's enabled.
if exists("syntax_on")
  syntax reset
endif

let colors_name = "default"
"
hi LineNr       cterm=none ctermfg=Cyan ctermbg=235 gui=NONE guifg=DarkGrey guibg=NONE      
" Creation des couleurs

hi Comment      ctermfg=14 guifg=black
hi Var          ctermfg=51 guifg=cyan
hi StatusLine   ctermfg=51 guifg=cyan
hi Constant     ctermfg=166 guifg=black
hi Identifier   ctermfg=39 cterm=none guifg=palegreen
hi Type         ctermfg=44 guifg=black
hi Statement    ctermfg=133 guifg=black
hi PreProc      ctermfg=14 guifg=black
hi Value      ctermfg=22 guifg=black
hi Pointer      ctermfg=88 guifg=black
hi Pmenu        ctermbg=51 guibg=cyan
hi PmenuSel     ctermfg=21 guifg=black
" vim: sw=2
