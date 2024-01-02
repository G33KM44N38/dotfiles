#!/usr/bin/env bash

# Function to display error and exit
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Check if fzf is installed
if ! command -v fzf &> /dev/null; then
    error_exit "fzf is not installed. Please install fzf to use this script."
fi

# Check the number of arguments
if [[ $# -eq 1 ]]; then
    selected=$1
else
    selected=$(find \
    ~/coding/ \
    ~/coding/* \
    ~/coding/work/minata/ \
    ~/coding/work/minata/src/* \
    ~/goinfre/ \
    ~/.dotfiles/ \
    -mindepth 1 -maxdepth 1 -type d | fzf) || error_exit "No directory selected."
fi

# Check if a selection is made
if [[ -z $selected ]]; then
    error_exit "No directory selected."
fi

selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux)

# Check if tmux is running
if [[ -n $TMUX ]] || [[ -n $tmux_running ]]; then
    if ! tmux has-session -t=$selected_name 2> /dev/null; then
        tmux new-session -ds $selected_name -c $selected
    fi
    tmux switch-client -t $selected_name
else
    tmux new-session -s $selected_name -c $selected
fi
