# TMUX Navigate
tmux-navigate() {
	tmux-navigate.sh
}
zle -N tmux-navigate
bindkey '^F' tmux-navigate
