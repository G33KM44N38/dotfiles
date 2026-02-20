#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_PATH="/Users/boss/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second_Brain"
DATABASE_PATH="/Users/boss/coding/work/database"

LAYOUT_ROOT_OPT="@layout-root"
LAYOUT_PROFILE_OPT="@layout-profile"
LAYOUT_INIT_OPT="@layout-initialized"
LAYOUT_MANAGED_OPT="@layout-managed"

TMUX_CLEANUP_SCRIPT="$HOME/.dotfiles/bin/tmux-cleanup.sh"
TMUX_SECONDARY_SCRIPT="$HOME/.dotfiles/bin/tmux-secondary-window.sh"
TMUX_SUPERVISE="$HOME/.dotfiles/bin/tmux-supervise"

usage() {
	cat <<'EOF' >&2
Usage:
  tmux_layout.sh init [session] [path]
  tmux_layout.sh ensure <index> [session] [path]
  tmux_layout.sh open <index> [session] [path]
  tmux_layout.sh reset [session] [path]
EOF
	exit 1
}

normalize_path() {
	local path="$1"
	path="${path%/}"
	[ -z "$path" ] && path="/"
	printf '%s\n' "$path"
}

resolve_session() {
	local requested="${1:-}"
	local session=""

	if [ -n "$requested" ]; then
		printf '%s\n' "$requested"
		return 0
	fi

	session="$(tmux display-message -p '#S' 2>/dev/null || true)"
	if [ -n "$session" ]; then
		printf '%s\n' "$session"
		return 0
	fi

	session="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -n1 || true)"
	printf '%s\n' "$session"
}

resolve_path() {
	local requested="${1:-}"
	local current_path=""

	if [ -n "$requested" ]; then
		normalize_path "$requested"
		return 0
	fi

	current_path="$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_current_path}' 2>/dev/null || true)"
	if [ -n "$current_path" ]; then
		normalize_path "$current_path"
		return 0
	fi

	normalize_path "$PWD"
}

window_exists() {
	local session="$1"
	local index="$2"
	tmux list-windows -t "$session" -F '#{window_index}' 2>/dev/null | grep -qx "$index"
}

set_session_layout_context() {
	local session="$1"
	local root="$2"
	local profile="$3"

	tmux set-option -q -t "$session" "$LAYOUT_ROOT_OPT" "$root"
	tmux set-option -q -t "$session" "$LAYOUT_PROFILE_OPT" "$profile"
}

get_session_layout_root() {
	local session="$1"
	local fallback="$2"
	local configured_root=""

	configured_root="$(tmux show-option -qv -t "$session" "$LAYOUT_ROOT_OPT" 2>/dev/null || true)"
	if [ -n "$configured_root" ]; then
		normalize_path "$configured_root"
		return 0
	fi

	normalize_path "$fallback"
}

detect_profile() {
	local root="$1"

	case "$root" in
		"$WORKSPACE_PATH"|"$WORKSPACE_PATH"/*)
			echo "second_brain"
			;;
		"$DATABASE_PATH"|"$DATABASE_PATH"/*)
			echo "database"
			;;
		*)
			echo "default"
			;;
	esac
}

get_session_profile() {
	local session="$1"
	local fallback_root="$2"
	local profile=""

	profile="$(tmux show-option -qv -t "$session" "$LAYOUT_PROFILE_OPT" 2>/dev/null || true)"
	if [ -n "$profile" ]; then
		printf '%s\n' "$profile"
		return 0
	fi

	detect_profile "$fallback_root"
}

window_spec() {
	local profile="$1"
	local index="$2"
	local name=""
	local command=""

	case "$index" in
		1)
			name="nvim"
			case "$profile" in
				second_brain)
					command="odn"
					;;
				database)
					command='vi -c ":DBUIToggle"'
					;;
				*)
					command="nvim ."
					;;
			esac
			;;
		2)
			case "$profile" in
				second_brain)
					name="opencode"
					command="$TMUX_SUPERVISE opencode"
					;;
				*)
					name="run"
					;;
			esac
			;;
		3)
			name="process"
			;;
		4)
			name="assistant"
			command="coding-assistant"
			;;
		*)
			return 1
			;;
	esac

	printf '%s\t%s\n' "$name" "$command"
}

create_window_if_missing() {
	local session="$1"
	local index="$2"
	local root="$3"
	local profile="$4"
	local spec name command

	if window_exists "$session" "$index"; then
		return 0
	fi

	spec="$(window_spec "$profile" "$index")" || return 0
	name="${spec%%$'\t'*}"
	command="${spec#*$'\t'}"

	[ -z "$name" ] && return 0

	tmux new-window -d -t "${session}:${index}" -n "$name" -c "$root"
	tmux set-option -wq -t "${session}:${index}" "$LAYOUT_MANAGED_OPT" "1"

	if [ -n "$command" ]; then
		tmux send-keys -t "${session}:${index}" -R "$command" C-m
	fi
}

init_layout() {
	local session="$1"
	local root="$2"
	local profile="$3"
	local initialized spec name command

	initialized="$(tmux show-option -qv -t "$session" "$LAYOUT_INIT_OPT" 2>/dev/null || true)"
	if [ "$initialized" = "1" ]; then
		return 0
	fi

	set_session_layout_context "$session" "$root" "$profile"

	spec="$(window_spec "$profile" 1)" || return 0
	name="${spec%%$'\t'*}"
	command="${spec#*$'\t'}"

	tmux rename-window -t "${session}:1" "$name"
	if [ -n "$command" ]; then
		tmux send-keys -t "${session}:1" -R "$command" C-m
	fi
	tmux set-option -wq -t "${session}:1" "$LAYOUT_MANAGED_OPT" "0"
	tmux set-option -q -t "$session" "$LAYOUT_INIT_OPT" "1"
}

open_window() {
	local session="$1"
	local index="$2"
	local root="$3"
	local profile="$4"

	if [ "$index" = "5" ]; then
		"$TMUX_SECONDARY_SCRIPT" "" "$session"
		return 0
	fi

	create_window_if_missing "$session" "$index" "$root" "$profile"
	tmux select-window -t "${session}:${index}"
}

is_legacy_managed_window() {
	local index="$1"
	local name="$2"
	case "$index:$name" in
		2:run|2:opencode|3:process|4:assistant)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

reset_layout() {
	local session="$1"
	local root="$2"
	local profile="$3"
	local window_rows row window_id window_index window_name managed secondary

	set_session_layout_context "$session" "$root" "$profile"

	window_rows="$(tmux list-windows -t "$session" -F '#{window_id}\t#{window_index}\t#{window_name}' 2>/dev/null || true)"
	[ -z "$window_rows" ] && return 0

	while IFS= read -r row; do
		[ -z "$row" ] && continue
		window_id="${row%%$'\t'*}"
		row="${row#*$'\t'}"
		window_index="${row%%$'\t'*}"
		window_name="${row#*$'\t'}"

		if [ "$window_index" = "1" ]; then
			continue
		fi

		managed="$(tmux show-options -w -t "$window_id" -v "$LAYOUT_MANAGED_OPT" 2>/dev/null || true)"
		secondary="$(tmux show-options -w -t "$window_id" -v @secondary-worktree-path 2>/dev/null || true)"

		if [ "$managed" = "1" ] || [ -n "$secondary" ] || is_legacy_managed_window "$window_index" "$window_name"; then
			"$TMUX_CLEANUP_SCRIPT" window "$session" "$window_index" >/dev/null 2>&1 || true
			tmux kill-window -t "${session}:${window_index}" >/dev/null 2>&1 || true
		fi
	done <<< "$window_rows"

	tmux select-window -t "${session}:1" >/dev/null 2>&1 || true
}

main() {
	local mode="${1:-init}"
	local index session root profile

	case "$mode" in
		init)
			session="$(resolve_session "${2:-}")"
			root="$(resolve_path "${3:-}")"
			[ -z "$session" ] && usage
			profile="$(detect_profile "$root")"
			init_layout "$session" "$root" "$profile"
			;;
		ensure)
			index="${2:-}"
			session="$(resolve_session "${3:-}")"
			root="$(resolve_path "${4:-}")"
			[ -z "$index" ] && usage
			[ -z "$session" ] && usage
			root="$(get_session_layout_root "$session" "$root")"
			profile="$(get_session_profile "$session" "$root")"
			create_window_if_missing "$session" "$index" "$root" "$profile"
			;;
		open)
			index="${2:-}"
			session="$(resolve_session "${3:-}")"
			root="$(resolve_path "${4:-}")"
			[ -z "$index" ] && usage
			[ -z "$session" ] && usage
			root="$(get_session_layout_root "$session" "$root")"
			profile="$(get_session_profile "$session" "$root")"
			open_window "$session" "$index" "$root" "$profile"
			;;
		reset)
			session="$(resolve_session "${2:-}")"
			root="$(resolve_path "${3:-}")"
			[ -z "$session" ] && usage
			profile="$(detect_profile "$root")"
			reset_layout "$session" "$root" "$profile"
			;;
		*)
			usage
			;;
	esac
}

main "$@"
