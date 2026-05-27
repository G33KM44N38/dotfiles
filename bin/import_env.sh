#!/bin/bash

# Define source directory
SOURCE_DIR="$HOME/.dotfiles/.group_env"

# Check if the directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Directory $SOURCE_DIR does not exist."
  exit 1
fi

if [ "$#" -gt 1 ]; then
  echo "Usage: $(basename "$0") [env-file]"
  exit 1
fi

if [ "$#" -eq 1 ]; then
  if [ -f "$1" ]; then
    SELECTED_FILE="$1"
  elif [ -f "$SOURCE_DIR/$1" ]; then
    SELECTED_FILE="$SOURCE_DIR/$1"
  else
    echo "File '$1' does not exist."
    exit 1
  fi
else
  # Check if fzf is installed
  if ! command -v fzf &> /dev/null; then
    echo "fzf is not installed. Please install it first."
    exit 1
  fi

  # Use fzf to select a file
  SELECTED_FILE=$(find "$SOURCE_DIR" -type f | fzf)
fi

# If the user didn't select anything, exit
if [ -z "$SELECTED_FILE" ]; then
  echo "No file selected."
  exit 0
fi

# Copy the selected file to the current directory
cp "$SELECTED_FILE" .env

echo "Copied $(basename "$SELECTED_FILE") to current directory."
