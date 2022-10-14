let g:startify_session_dir = "~/.config/nvim/sessions/"
let g:startify_lists = [
        \ { 'type': 'sessions',  'header': ['   Sessions']       },
        \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      },
        \ { 'type': 'commands',  'header': ['   Commands']       },
        \ ]

let g:startify_bookmarks = [
	\ {'i': '~/.dotfiles/.config/nvim/init.vim'},
	\ {'p': '~/.dotfiles/.config/nvim/lua/plugin.lua'},
	\ {'n': '~/.dotfiles/.config/nvim/my_snip/cpp.snippets'},
	\ {'m': '~/.dotfiles/.config/nvim/after/plugin/nmap.vim'},
	\ {'l': '~/.dotfiles/.config/nvim/lua/init.lua'},
	\ {'s': '~/.dotfiles/.config/nvim/after/plugin/startity_config.vim'},
	\ {'t': '~/.dotfiles/tmux/.tmux.conf'},
	\ {'f': '~/.dotfiles/.config/fish/config.fish'},
	\ ]
let g:startify_custom_header = [
	\ ' ███╗   ██╗ ███████╗ ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗',
	\ ' ████╗  ██║ ██╔════╝██╔═══██╗ ██║   ██║ ██║ ████╗ ████║',
	\ ' ██╔██╗ ██║ █████╗  ██║   ██║ ██║   ██║ ██║ ██╔████╔██║',
	\ ' ██║╚██╗██║ ██╔══╝  ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║',
	\ ' ██║ ╚████║ ███████╗╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║',
	\ ' ╚═╝  ╚═══╝ ╚══════╝ ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝',
	\]

