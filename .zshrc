# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/bin:$PATH"

ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh

# Constants for Paths
export config_dir=~/.config/zsh


# Source Configurations
source $config_dir/path.zsh
source $config_dir/alias.zsh
source $config_dir/keymap.zsh

# Editor Configuration
export EDITOR='nvim'
export VISUAL='nvim'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
