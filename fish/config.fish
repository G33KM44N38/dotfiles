set -g fish_greeting "Welcome lord Kylian Let's code 💻"

set EDITOR 'nvim'
set VISUAL 'nvim'

source ~/.config/fish/path.fish
source ~/.config/fish/alias.fish
source ~/.config/fish/keymap.fish
source ~/.config/fish/function.fish

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
