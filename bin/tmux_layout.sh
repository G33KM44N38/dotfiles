#!/bin/bash

# Absolute path to skip
WORKSPACE_PATH="/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"

# Get current directory full path
CURRENT_DIR="$PWD"

# List of full paths where we skip creating extra tmux windows
EXCLUDED_PATHS=(
  "$WORKSPACE_PATH|odn"
  "/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain|odn"
  "/Users/boss/.dotfiles/bin/create-todo|npm run dev"
)

# Check if current path is in the excluded list
# To add a new excluded path and its custom command, add a new line like:
# EXCLUDED_PATHS["/path/to/your/project"]="your_custom_command"
# To remove an entry, simply delete the corresponding line.
should_exclude=false
for entry in "${EXCLUDED_PATHS[@]}"; do
  IFS='|' read -r excluded_path command_to_run <<< "$entry"
  if [[ "$CURRENT_DIR" == "$excluded_path" ]]; then
    should_exclude=true
    SPECIFIC_COMMAND="$command_to_run"
    break
  fi
done

tmux rename-window 'nvim'
if [[ "$should_exclude" == true ]]; then
  tmux send-keys -R "$SPECIFIC_COMMAND" C-m
else
  tmux send-keys -R "nvim ." C-m
fi

# Only create extra windows if not excluded
if [[ "$should_exclude" == false ]]; then
  tmux new-window -n 'run'
  tmux new-window -n 'process'
  # tmux new-window -n 'AI'
  # tmux send-keys -R "gemini" C-m
  tmux new-window -n 'assistant'
  tmux send-keys -R "coding-assistant" C-m
fi

tmux select-window -t 1
