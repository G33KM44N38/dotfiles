#!/usr/bin/env bash

set -euo pipefail

tmux_bin="$(command -v tmux 2>/dev/null || true)"
[ -n "$tmux_bin" ] || tmux_bin="/opt/homebrew/bin/tmux"

fail() {
	local message="$1"
	echo "$message" >&2
	if [ -n "${TMUX:-}" ] && [ -x "$tmux_bin" ]; then
		"$tmux_bin" display-message "$message" >/dev/null 2>&1 || true
	fi
	exit 1
}

[ -x "$tmux_bin" ] || fail "root worktree: tmux not found"
"$tmux_bin" list-sessions >/dev/null 2>&1 || fail "root worktree: tmux server not available"

source_session="${1:-}"
source_path="${2:-}"

if [ -z "$source_session" ]; then
	source_session="$("$tmux_bin" display-message -p '#S' 2>/dev/null || true)"
fi

if [ -z "$source_path" ]; then
	source_path="$("$tmux_bin" display-message -p -t "${TMUX_PANE:-}" '#{pane_current_path}' 2>/dev/null || true)"
fi
[ -n "$source_path" ] || source_path="$PWD"

normalize_existing_path() {
	local path="$1"
	while [ ! -e "$path" ] && [ "$path" != "/" ]; do
		path="$(dirname "$path")"
	done
	[ -e "$path" ] && printf '%s\n' "$path"
}

source_path="$(normalize_existing_path "$source_path" || true)"
[ -n "$source_path" ] || fail "root worktree: invalid source path"

git_common_dir="$(git -C "$source_path" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$git_common_dir" ] && [ "${git_common_dir#/}" = "$git_common_dir" ]; then
	git_common_dir="$(cd "$source_path" && cd "$git_common_dir" 2>/dev/null && pwd || true)"
fi

worktree_root=""
if [ -n "$git_common_dir" ] && [ -d "$git_common_dir" ] && git -C "$git_common_dir" rev-parse --is-bare-repository 2>/dev/null | grep -qx true; then
	worktree_root="$git_common_dir"
fi

if [ -z "$worktree_root" ]; then
	worktree_root="$(git -C "$source_path" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$worktree_root" ] || fail "root worktree: not in a git repository"

branch="$(git -C "$worktree_root" branch --show-current 2>/dev/null || true)"
[ -n "$branch" ] || branch="$(basename "$worktree_root")"

exec "$HOME/.dotfiles/bin/tmux-worktree-layout.sh" open "$source_session" "$worktree_root" "$branch" 1
