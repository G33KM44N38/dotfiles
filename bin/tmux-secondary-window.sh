#!/usr/bin/env bash

set -euo pipefail

tmux_bin="$(command -v tmux 2>/dev/null || true)"
if [ -z "$tmux_bin" ]; then
	for candidate in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux; do
		if [ -x "$candidate" ]; then
			tmux_bin="$candidate"
			break
		fi
	done
fi

if [ -z "$tmux_bin" ] || ! "$tmux_bin" list-sessions >/dev/null 2>&1; then
	echo "Error: tmux-secondary-window.sh requires an active tmux server/session" >&2
	exit 1
fi

tmux_supervise="$HOME/.dotfiles/bin/tmux-supervise"

explicit_worktree="${1:-}"
explicit_session="${2:-}"
session_name="$explicit_session"
if [ -z "$session_name" ]; then
	session_name="$("$tmux_bin" show-option -gv @secondary-session 2>/dev/null || true)"
fi
if [ -z "$session_name" ]; then
	session_name="$("$tmux_bin" display-message -p '#S' 2>/dev/null || true)"
fi
if [ -z "$session_name" ]; then
	session_name="$("$tmux_bin" list-sessions -F '#{session_name}' 2>/dev/null | head -n1 || true)"
fi
if [ -z "$session_name" ]; then
	echo "Error: unable to resolve tmux session for secondary window" >&2
	exit 1
fi

current_path="$explicit_worktree"
if [ -z "$current_path" ]; then
	current_path="$("$tmux_bin" show-option -gv @secondary-worktree 2>/dev/null || true)"
fi
if [ -z "$current_path" ]; then
	current_path="$("$tmux_bin" display-message -p -t "${TMUX_PANE:-}" '#{pane_current_path}' 2>/dev/null || pwd)"
fi

secondary_agent="$("$tmux_bin" show-option -gv @secondary-agent 2>/dev/null || true)"
secondary_worktree="$("$tmux_bin" show-option -gv @secondary-worktree 2>/dev/null || true)"

if [ -z "$secondary_agent" ]; then
	secondary_agent="codex"
fi

resolve_target_worktree() {
	local cwd="$1"
	local configured="$2"

	local current_root
	current_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
	if [ -z "$current_root" ]; then
		if [ -n "$configured" ] && [ -d "$configured" ]; then
			printf '%s\n' "$configured"
			return 0
		fi
		printf '%s\n' "$cwd"
		return 0
	fi

	if [ -n "$configured" ]; then
		if [ -d "$configured" ]; then
			printf '%s\n' "$configured"
			return 0
		fi
		if [ -d "$current_root/$configured" ]; then
			printf '%s\n' "$current_root/$configured"
			return 0
		fi
	fi

	local candidate
	while IFS= read -r candidate; do
		if [ "$candidate" != "$current_root" ] && [ -d "$candidate" ]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done < <(git -C "$current_root" worktree list --porcelain 2>/dev/null | awk '/^worktree / {print substr($0, 10)}')

	printf '%s\n' "$current_root"
}

find_window_for_worktree() {
	local worktree="$1"
	local window_id
	while IFS= read -r window_id; do
		[ -z "$window_id" ] && continue
		local wt
		wt="$("$tmux_bin" show-options -w -t "$window_id" -v @secondary-worktree-path 2>/dev/null || true)"
		if [ "$wt" = "$worktree" ]; then
			"$tmux_bin" display-message -p -t "$window_id" '#{window_index}'
			return 0
		fi
	done < <("$tmux_bin" list-windows -t "$session_name" -F '#{window_id}')
	return 1
}

sanitize_window_label() {
	local label="$1"
	label="$(printf '%s' "$label" | tr '[:space:]' '-' | tr -cd 'A-Za-z0-9._-')"
	if [ -z "$label" ]; then
		label="secondary"
	fi
	printf '%s\n' "$label"
}

if [ -n "$explicit_worktree" ] && [ -d "$explicit_worktree" ]; then
	target_worktree="$explicit_worktree"
else
	target_worktree="$(resolve_target_worktree "$current_path" "$secondary_worktree")"
	if [ ! -d "$target_worktree" ]; then
		target_worktree="$current_path"
	fi
fi

secondary_window="$(find_window_for_worktree "$target_worktree" || true)"

if [ -z "${secondary_window:-}" ]; then
	window_label="$(basename "$target_worktree")"
	if [ -z "$window_label" ] || [ "$window_label" = "/" ]; then
		window_label="secondary"
	fi
	window_label="$(sanitize_window_label "$window_label")"
	window_name="secondary-$window_label"

	if ! "$tmux_bin" list-windows -t "$session_name" -F '#{window_index}' | grep -qx '5'; then
		"$tmux_bin" new-window -d -t "${session_name}:5" -n "$window_name" -c "$target_worktree"
		secondary_window="5"
	else
		secondary_window="$("$tmux_bin" new-window -d -P -F '#{window_index}' -t "$session_name" -n "$window_name" -c "$target_worktree")"
	fi

	"$tmux_bin" set-option -wq -t "${session_name}:${secondary_window}" @secondary-worktree-path "$target_worktree"

	printf -v launch_cmd 'cd %q && %q %q' "$target_worktree" "$tmux_supervise" "$secondary_agent"
	"$tmux_bin" send-keys -t "${session_name}:${secondary_window}" -R "$launch_cmd" C-m
fi

"$tmux_bin" select-window -t "${session_name}:${secondary_window}"
if [ "$("$tmux_bin" display-message -p -t "${session_name}:${secondary_window}" '#{window_zoomed_flag}')" = "0" ]; then
	"$tmux_bin" resize-pane -Z -t "${session_name}:${secondary_window}"
fi
