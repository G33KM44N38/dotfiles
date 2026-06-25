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

usage() {
	echo "Usage: tmux-repo-worktree.sh <main|release> [source-session] [source-path]" >&2
	exit 2
}

[ $# -ge 1 ] || usage

slot="$1"
source_session="${2:-}"
source_path="${3:-}"
window_index=""

case "$slot" in
	main) window_index="3" ;;
	release) window_index="4" ;;
	*) usage ;;
esac

[ -x "$tmux_bin" ] || fail "repo worktree: tmux not found"
"$tmux_bin" list-sessions >/dev/null 2>&1 || fail "repo worktree: tmux server not available"

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
[ -n "$source_path" ] || fail "repo worktree: invalid source path"

git_common_dir="$(git -C "$source_path" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$git_common_dir" ] && [ "${git_common_dir#/}" = "$git_common_dir" ]; then
	git_common_dir="$(cd "$source_path" && cd "$git_common_dir" 2>/dev/null && pwd || true)"
fi

repo_root="$(git -C "$source_path" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ] && [ -n "$git_common_dir" ] && git -C "$git_common_dir" worktree list --porcelain >/dev/null 2>&1; then
	repo_root="$git_common_dir"
fi
[ -n "$repo_root" ] || fail "repo worktree: not in a git repository"

selector="$(git -C "$repo_root" config --get "tmux.worktree.$slot" 2>/dev/null || true)"
[ -n "$selector" ] || selector="$slot"

resolve_selector_path() {
	local value="$1"
	local candidate

	if [ "${value#/}" != "$value" ] && [ -d "$value" ]; then
		printf '%s\n' "$value"
		return 0
	fi

	candidate="$repo_root/$value"
	if [ -d "$candidate" ]; then
		printf '%s\n' "$candidate"
		return 0
	fi

	if [ -n "${git_common_dir:-}" ]; then
		candidate="$(dirname "$git_common_dir")/$value"
		if [ -d "$candidate" ]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	fi

	return 1
}

target_path="$(resolve_selector_path "$selector" || true)"
target_branch="$selector"

if [ -z "$target_path" ]; then
	while IFS=$'\t' read -r worktree_path branch_name; do
		[ -n "$worktree_path" ] || continue
		if [ "$branch_name" = "$selector" ] && [ -d "$worktree_path" ]; then
			target_path="$worktree_path"
			target_branch="$branch_name"
			break
		fi
	done < <(
		git -C "$repo_root" worktree list --porcelain | awk '
			BEGIN { path=""; branch="" }
			function emit() {
				if (path != "" && branch != "") print path "\t" branch
			}
			/^worktree / {
				emit()
				path = substr($0, 10)
				branch = ""
				next
			}
			/^branch / {
				branch = substr($0, 8)
				sub(/^refs\/heads\//, "", branch)
				next
			}
			END { emit() }
		'
	)
fi

[ -n "$target_path" ] || fail "repo worktree: no worktree found for $slot selector '$selector'"

exec "$HOME/.dotfiles/bin/tmux-worktree-layout.sh" open "$source_session" "$target_path" "$target_branch" "$window_index"
