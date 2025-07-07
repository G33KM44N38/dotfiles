#!/bin/bash

# Absolute path to skip
WORKSPACE_PATH="/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"

tmux rename-window 'nvim'
tmux send-keys -R "nvim ." C-m

# Get current directory full path
CURRENT_DIR="$PWD"

# List of full paths where we skip creating extra tmux windows
EXCLUDED_PATHS=("$WORKSPACE_PATH")

# Check if current path is in the excluded list
should_exclude=false
for path in "${EXCLUDED_PATHS[@]}"; do
  if [[ "$CURRENT_DIR" == "$path" ]]; then
    should_exclude=true
    break
  fi
done

# Only create extra windows if not excluded
if [[ "$should_exclude" == false ]]; then
  tmux new-window -n 'run'
  tmux new-window -n 'process'
  tmux new-window -n 'AI'
  tmux send-keys -R "npx https://github.com/google-gemini/gemini-cli" C-m
fi

tmux select-window -t 1
