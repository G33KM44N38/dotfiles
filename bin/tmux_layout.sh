#!/bin/bash

# Absolute path to skip
WORKSPACE_PATH="/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"
DATABASE_PATH="/Users/boss/coding/work/database"

# Get current directory full path
CURRENT_DIR="$PWD"
SPECIFIC_COMMAND="nvim ."
should_exclude=false

case "$CURRENT_DIR" in
  "$WORKSPACE_PATH")
    should_exclude=true
    SPECIFIC_COMMAND="odn"
    ;;
  "$DATABASE_PATH")
    should_exclude=true
    SPECIFIC_COMMAND='vi -c ":DBUIToggle"'
    ;;
esac

if [[ "$should_exclude" == true ]]; then
  tmux rename-window 'nvim' \; send-keys -R "$SPECIFIC_COMMAND" C-m \; select-window -t 1
else
  tmux rename-window 'nvim' \
    \; send-keys -R "$SPECIFIC_COMMAND" C-m \
    \; new-window -n 'run' \
    \; new-window -n 'process' \
    \; new-window -n 'assistant' \
    \; send-keys -t 'assistant' -R "coding-assistant" C-m \
    \; select-window -t 1
fi
