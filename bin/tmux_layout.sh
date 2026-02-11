#!/bin/bash

WORKSPACE_PATH="/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"
DATABASE_PATH="/Users/boss/coding/work/database"

CURRENT_DIR="$PWD"
SPECIFIC_COMMAND="nvim ."

case "$CURRENT_DIR" in
  "$WORKSPACE_PATH")
    tmux rename-window 'nvim' \
      \; send-keys -R "odn" C-m \
      \; new-window -n 'opencode' \
      \; send-keys -t 'opencode' -R "opencode" C-m \
      \; select-window -t 1
    ;;
    
  "$DATABASE_PATH")
    tmux rename-window 'nvim' \
      \; send-keys -R 'vi -c ":DBUIToggle"' C-m \
      \; select-window -t 1
    ;;
    
  *)
    tmux rename-window 'nvim' \
      \; send-keys -R "$SPECIFIC_COMMAND" C-m \
      \; new-window -n 'run' \
      \; new-window -n 'process' \
      \; new-window -n 'assistant' \
      \; send-keys -t 'assistant' -R "coding-assistant" C-m \
      \; select-window -t 1
    ;;
esac
