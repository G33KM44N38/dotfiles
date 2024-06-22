#!/usr/bin/env bash

if [[ $# -eq 1 ]]; then
    selected=$1
else
selected=$(find \
    ~/keyboard/ \
    ~/coding/ \
    ~/coding/* \
    ~/goinfre/ \
    ~/.dotfiles/ \
    ~/.dotfiles/* \
    ~/.dotfiles/.config/ \
    ~/SecondBrain/ \
    -mindepth 1 -maxdepth 1 -type d | fzf)
fi

if [[ -z $selected ]]; then
    exit 0
fi

selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux)

if ! [[ -n $TMUX ]]; then
	if tmux has-session -t=$selected_name 2> /dev/null; then
		tmux a -t $selected_name
	else
	    tmux new-session -s $selected_name -c $selected
	fi
else
	if tmux has-session -t=$selected_name 2> /dev/null; then
		tmux switch-client -t $selected_name
	else
	    tmux new -s $selected_name -d -c $selected
	    tmux switch-client -t $selected_name 
	fi
fi
