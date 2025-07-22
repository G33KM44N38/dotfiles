#!/bin/zsh

set -e

# Define source paths
ROOT="$HOME/.config/AI/GEMINI"
FILES_TO_LINK=("GEMINI.md" ".gemini")

# Get the .git/info path, even in worktrees
get_git_info_dir() {
  local git_dir
  git_dir=$(git rev-parse --git-dir) || {
    echo "❌ Not inside a Git repository."
    exit 1
  }

  if [[ -f "$git_dir" ]]; then
    git_dir=$(grep "gitdir: " "$git_dir" | sed 's/gitdir: //')
  fi

  echo "$git_dir/info"
}

# Get .git/info path and ensure exclude file exists
GIT_INFO_DIR=$(get_git_info_dir)
EXCLUDE_FILE="$GIT_INFO_DIR/exclude"
mkdir -p "$GIT_INFO_DIR"
touch "$EXCLUDE_FILE"

# Loop through each file/folder to link and exclude
for ITEM in "${FILES_TO_LINK[@]}"; do
  TARGET="$ROOT/$ITEM"
  LINK_NAME="./$ITEM"

  if [[ -e "$LINK_NAME" || -L "$LINK_NAME" ]]; then
    echo "❌ '$LINK_NAME' already exists. Skipping."
  else
    ln -s "$TARGET" "$LINK_NAME"
    echo "✅ Linked: $LINK_NAME → $TARGET"
  fi

  # Exclude from Git if not already excluded
  if ! grep -Fxq "$ITEM" "$EXCLUDE_FILE"; then
    echo "$ITEM" >> "$EXCLUDE_FILE"
    echo "✅ Added '$ITEM' to $EXCLUDE_FILE"
  else
    echo "ℹ️  '$ITEM' already excluded in $EXCLUDE_FILE"
  fi
done
