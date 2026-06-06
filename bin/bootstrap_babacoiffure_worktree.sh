#!/usr/bin/env bash

set -euo pipefail

worktree="${1:-}"
[ -n "$worktree" ] || exit 0
[ -d "$worktree" ] || exit 0

remote_url="$(git -C "$worktree" remote get-url origin 2>/dev/null || true)"
case "$remote_url" in
	*babacoiffure/babacoiffure_monorepo*|*babacoiffure_monorepo*)
		;;
	*)
		exit 0
		;;
esac

(
	cd "$worktree"
	"$HOME/.dotfiles/bin/import_babacoiffure_local.sh"

	if [ -f pnpm-lock.yaml ] && [ ! -d node_modules ]; then
		pnpm install
	fi
)
