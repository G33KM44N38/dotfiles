#!/usr/bin/env bash

set -euo pipefail

tmux_bin="$(command -v tmux 2>/dev/null || true)"

fail() {
	local message="$1"
	echo "$message" >&2
	if [ -n "${TMUX:-}" ] && [ -n "$tmux_bin" ]; then
		"$tmux_bin" display-message "$message" >/dev/null 2>&1 || true
	fi
	exit 1
}

[ -n "$tmux_bin" ] || fail "worktree layout: tmux not found"
"$tmux_bin" list-sessions >/dev/null 2>&1 || fail "worktree layout: tmux server not available"

sanitize_name() {
	printf '%s\n' "$1" \
		| tr '/[:space:]' '--' \
		| tr . _ \
		| tr -cd 'A-Za-z0-9._-' \
		| sed 's/^-*//; s/-*$//'
}

repo_root() {
	git -C "$1" rev-parse --show-toplevel 2>/dev/null || true
}

project_root() {
	local path="$1"
	local common_dir top

	common_dir="$(git -C "$path" rev-parse --git-common-dir 2>/dev/null || true)"
	if [ -n "$common_dir" ]; then
		if [ "${common_dir#/}" = "$common_dir" ]; then
			common_dir="$(cd "$path" && cd "$common_dir" 2>/dev/null && pwd || true)"
		fi
		if [ -n "$common_dir" ] && [ -d "$common_dir" ]; then
			case "$(basename "$common_dir")" in
				.git)
					top="$(repo_root "$path")"
					[ -n "$top" ] && printf '%s\n' "$top"
					;;
				*)
					printf '%s\n' "$common_dir"
					;;
			esac
			return 0
		fi
	fi

	top="$(repo_root "$path")"
	[ -n "$top" ] && printf '%s\n' "$top"
}

session_for_path() {
	local path="$1"
	local root name

	root="$(project_root "$path")"
	[ -n "$root" ] || root="$path"
	name="$(sanitize_name "$(basename "$root")")"
	[ -n "$name" ] || name="project"
	printf '%s\n' "$name"
}

next_window_index() {
	local session="$1"
	local candidate="${2:-6}"
	local used_indexes

	used_indexes="$("$tmux_bin" list-windows -t "$session" -F '#{window_index}' 2>/dev/null || true)"
	while printf '%s\n' "$used_indexes" | grep -qx "$candidate"; do
		candidate=$((candidate + 1))
	done
	printf '%s\n' "$candidate"
}

window_for_worktree() {
	local worktree="$1"
	local window_id tagged_path pane_path pane_root

	while IFS=$'\t' read -r window_id pane_path; do
		[ -n "$window_id" ] || continue

		tagged_path="$("$tmux_bin" show-options -w -t "$window_id" -v @secondary-worktree-path 2>/dev/null || true)"
		if [ "$tagged_path" = "$worktree" ]; then
			"$tmux_bin" display-message -p -t "$window_id" '#{session_name}:#{window_index}'
			return 0
		fi

		pane_root="$(repo_root "$pane_path")"
		if [ -n "$pane_root" ] && [ "$pane_root" = "$worktree" ]; then
			"$tmux_bin" display-message -p -t "$window_id" '#{session_name}:#{window_index}'
			return 0
		fi
	done < <("$tmux_bin" list-windows -a -F '#{window_id}'$'\t''#{pane_current_path}' 2>/dev/null)

	return 1
}

open_layout() {
	local source_session="$1"
	local worktree="$2"
	local branch="${3:-}"
	local target_session existing_window window_index window_name created_window
	local top_left_pane top_right_pane bottom_left_pane bottom_right_pane
	local vi_cmd co_cmd bootstrap_cmd project_path

	[ -d "$worktree" ] || fail "worktree layout: invalid worktree path: $worktree"

	existing_window="$(window_for_worktree "$worktree" || true)"
	if [ -n "$existing_window" ]; then
		"$tmux_bin" switch-client -t "$existing_window" >/dev/null 2>&1 || "$tmux_bin" select-window -t "$existing_window" >/dev/null 2>&1 || true
		if [ "$("$tmux_bin" display-message -p -t "$existing_window" '#{window_zoomed_flag}' 2>/dev/null || true)" = "1" ]; then
			"$tmux_bin" resize-pane -Z -t "$existing_window" >/dev/null 2>&1 || true
		fi
		return 0
	fi

	target_session="$(session_for_path "$worktree")"
	if ! "$tmux_bin" has-session -t "$target_session" 2>/dev/null; then
		project_path="$(project_root "$worktree")"
		[ -n "$project_path" ] || project_path="$worktree"
		"$tmux_bin" new-session -d -s "$target_session" -c "$project_path"
	fi

	"$tmux_bin" set-option -q -t "$target_session" @secondary-worktree "$worktree"
	"$tmux_bin" set-option -q -t "$target_session" @secondary-session "$target_session"
	if [ -n "$source_session" ] && "$tmux_bin" has-session -t "$source_session" 2>/dev/null; then
		"$tmux_bin" set-option -q -t "$source_session" @secondary-worktree "$worktree"
		"$tmux_bin" set-option -q -t "$source_session" @secondary-session "$target_session"
	fi

	window_index="$(next_window_index "$target_session" 6)"
	window_name="$(sanitize_name "$branch")"
	if [ -z "$window_name" ] || [ "$window_name" = "-" ]; then
		window_name="$(sanitize_name "$(basename "$worktree")")"
	fi
	[ -n "$window_name" ] || window_name="thread"

	created_window="$("$tmux_bin" new-window -d -P -F '#{window_index}' -t "${target_session}:${window_index}" -n "$window_name" -c "$worktree" 2>/dev/null || true)"
	[ -n "$created_window" ] || fail "worktree layout: failed to create window in session $target_session"
	"$tmux_bin" set-option -wq -t "${target_session}:${created_window}" @secondary-worktree-path "$worktree"

	top_left_pane="$("$tmux_bin" display-message -p -t "${target_session}:${created_window}" '#{pane_id}')"
	top_right_pane="$("$tmux_bin" split-window -h -d -P -F '#{pane_id}' -t "$top_left_pane" -c "$worktree")"
	bottom_left_pane="$("$tmux_bin" split-window -v -d -P -F '#{pane_id}' -t "$top_left_pane" -c "$worktree")"
	bottom_right_pane="$("$tmux_bin" split-window -v -d -P -F '#{pane_id}' -t "$top_right_pane" -c "$worktree")"

	"$tmux_bin" select-layout -t "${target_session}:${created_window}" tiled >/dev/null 2>&1 || true

	printf -v vi_cmd 'cd %q && vi .' "$worktree"
	printf -v co_cmd 'cd %q && co' "$worktree"
	printf -v bootstrap_cmd 'cd %q && %q %q' "$worktree" "$HOME/.dotfiles/bin/bootstrap_local_worktree.sh" "$worktree"

	sleep 0.1
	"$tmux_bin" send-keys -t "$top_left_pane" -R "$vi_cmd" C-m
	"$tmux_bin" send-keys -t "$top_right_pane" -R "$co_cmd" C-m
	"$tmux_bin" send-keys -t "$bottom_left_pane" -R "$bootstrap_cmd" C-m

	"$tmux_bin" switch-client -t "${target_session}:${created_window}" >/dev/null 2>&1 || "$tmux_bin" select-window -t "${target_session}:${created_window}" >/dev/null 2>&1 || true
	"$tmux_bin" select-pane -t "$bottom_left_pane"
	[ -n "$bottom_right_pane" ] || true
}

case "${1:-}" in
	open)
		open_layout "${2:-}" "${3:-}" "${4:-}"
		;;
	*)
		echo "Usage: tmux-worktree-layout.sh open <source-session> <worktree-path> [branch]" >&2
		exit 2
		;;
esac
