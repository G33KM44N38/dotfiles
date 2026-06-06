#!/usr/bin/env bash

set -euo pipefail

worktree="${1:-}"
[ -n "$worktree" ] || exit 0
[ -d "$worktree" ] || exit 0

remote_url="$(git -C "$worktree" remote get-url origin 2>/dev/null || true)"
case "$remote_url" in
	*dorali-app/dorali*|*dorali*)
		;;
	*)
		exit 0
		;;
esac

(
	cd "$worktree"
	"$HOME/.dotfiles/bin/import_dorali.sh"

	if [ -f pnpm-lock.yaml ] && [ ! -d node_modules ]; then
		pnpm install
	fi
)
