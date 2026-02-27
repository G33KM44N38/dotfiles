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

if [ -z "$tmux_bin" ]; then
	exit 0
fi

is_ignored_command() {
	case "${1:-}" in
		""|zsh|bash|sh|dash|fish|ksh|nu|pwsh|tmux|nvim|vim|vi|codex|opencode|lazygit|fzf|less|man)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

emit_window_status() {
	local window_target="$1"
	local pane_cmds pane_cmd

	pane_cmds="$("$tmux_bin" list-panes -t "$window_target" -F '#{pane_current_command}' 2>/dev/null || true)"
	[ -z "$pane_cmds" ] && return 0

	while IFS= read -r pane_cmd; do
		[ -z "$pane_cmd" ] && continue
		if ! is_ignored_command "$pane_cmd"; then
			printf '🏃'
			return 0
		fi
	done <<< "$pane_cmds"
}

emit_pane_status() {
	local pane_target="$1"
	local pane_cmd

	pane_cmd="$("$tmux_bin" display-message -p -t "$pane_target" '#{pane_current_command}' 2>/dev/null || true)"
	[ -z "$pane_cmd" ] && return 0

	if ! is_ignored_command "$pane_cmd"; then
		printf '🏃'
	fi
}

target="${1:-}"
if [ -z "$target" ]; then
	target="$("$tmux_bin" display-message -p '#{pane_id}' 2>/dev/null || true)"
fi

case "$target" in
	@*)
		emit_window_status "$target"
		;;
	%*)
		emit_pane_status "$target"
		;;
	*)
		emit_window_status "$target"
		;;
esac
