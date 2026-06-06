#!/usr/bin/env bash

set -euo pipefail

worktree="${1:-}"
[ -n "$worktree" ] || exit 0
[ -d "$worktree" ] || exit 0

"$HOME/.dotfiles/bin/bootstrap_babacoiffure_worktree.sh" "$worktree"
"$HOME/.dotfiles/bin/bootstrap_dorali_worktree.sh" "$worktree"
