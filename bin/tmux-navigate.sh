#!/usr/bin/env bash

# # Enable debug output
# set -x

if [[ $# -eq 1 ]]; then
    selected=$1
else
selected=$(find \
    "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/" \
    ~/backup/ \
    ~/coding/ \
    ~/coding/* \
    ~/goinfre/ \
    ~/.dotfiles/ \
    ~/.dotfiles/* \
    ~/.dotfiles/.config/ \
    -mindepth 1 -maxdepth 1 -type d | fzf)
fi

if [[ -z $selected ]]; then
    echo "No directory selected" >&2
    exit 0
fi

selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux)

# Clean up the path by removing trailing slashes
selected=$(echo "$selected" | sed 's:/*$::')

# Check if already in a tmux session
if [[ -z "$TMUX" ]]; then
    # Not in tmux session
    if tmux has-session -t="$selected_name" 2> /dev/null; then
        tmux attach-session -t "$selected_name"
    else
        tmux new-session -s "$selected_name" -c "$selected"
    fi
else
    # Already in tmux session
    if tmux has-session -t="$selected_name" 2> /dev/null; then
        tmux switch-client -t "$selected_name"
    else
        tmux new-session -d -s "$selected_name" -c "$selected"
        tmux switch-client -t "$selected_name"
    fi
fi
