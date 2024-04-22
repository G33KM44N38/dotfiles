# Constants for Paths
set config_dir ~/.config/fish

# Fish Greeting
set -g fish_greeting "Welcome, Lord Kylian! 💻"

# Editor Configuration
set EDITOR 'nvim'
set VISUAL 'nvim'

# Source Configurations
source $config_dir/path.fish
source $config_dir/alias.fish
source $config_dir/keymap.fish

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /opt/homebrew/Caskroom/miniconda/base/bin/conda
    eval /opt/homebrew/Caskroom/miniconda/base/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
        . "/opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/opt/homebrew/Caskroom/miniconda/base/bin" $PATH
    end
end
# <<< conda initialize <<<

