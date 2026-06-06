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

[ -z "$tmux_bin" ] && exit 0

role="${1:-top-left}"
window_target="${2:-}"
mode="${3:-smart-zoom}"
layout_commands="${4:-commands}"

case "$role" in
	top-left|top-right|bottom|bottom-right) ;;
	*) exit 0 ;;
esac

case "$mode" in
	focus|layout|smart-zoom) ;;
	*) exit 0 ;;
esac

if [ -z "$window_target" ]; then
	window_target="$("$tmux_bin" display-message -p '#{window_id}' 2>/dev/null || true)"
fi
[ -z "$window_target" ] && exit 0

created_top_right=0

pick_pane() {
	local target_role="$1"
	"$tmux_bin" list-panes -t "$window_target" -F '#{pane_id}'$'\t''#{pane_top}'$'\t''#{pane_left}' 2>/dev/null | \
		sort -t "$(printf '\t')" -k2,2n -k3,3n | \
		awk -F'\t' -v mode="$target_role" '
			BEGIN { best_id = ""; best_top = -1; best_left = -1 }
			{
				id = $1
				top = $2 + 0
				left = $3 + 0
				if (best_id == "") {
					best_id = id
					best_top = top
					best_left = left
					next
				}
				if (mode == "top-left" && (top < best_top || (top == best_top && left < best_left))) {
					best_id = id; best_top = top; best_left = left; next
				}
				if (mode == "top-right" && (top < best_top || (top == best_top && left > best_left))) {
					best_id = id; best_top = top; best_left = left; next
				}
				if (mode == "bottom" && (top > best_top || (top == best_top && left < best_left))) {
					best_id = id; best_top = top; best_left = left; next
				}
				if (mode == "bottom-right" && (top > best_top || (top == best_top && left > best_left))) {
					best_id = id; best_top = top; best_left = left; next
				}
			}
			END { if (best_id != "") print best_id }
		'
}

window_zoomed_flag() {
	"$tmux_bin" display-message -p -t "$window_target" '#{window_zoomed_flag}' 2>/dev/null || true
}

current_pane_id() {
	"$tmux_bin" display-message -p -t "$window_target" '#{pane_id}' 2>/dev/null || true
}

unzoom_window() {
	local pane_id
	pane_id="$(current_pane_id)"
	[ -n "$pane_id" ] || return 0
	"$tmux_bin" resize-pane -Z -t "$pane_id" >/dev/null 2>&1 || true
}

top_row_count() {
	"$tmux_bin" list-panes -t "$window_target" -F '#{pane_top}' 2>/dev/null | \
		awk 'NR == 1 { min = $1 } $1 < min { min = $1 } { rows[NR] = $1 } END { c = 0; for (i in rows) if (rows[i] == min) c++; print c + 0 }'
}

bottom_row_count() {
	"$tmux_bin" list-panes -t "$window_target" -F '#{pane_top}' 2>/dev/null | \
		awk 'NR == 1 { max = $1 } $1 > max { max = $1 } { rows[NR] = $1 } END { c = 0; for (i in rows) if (rows[i] == max) c++; print c + 0 }'
}

has_top_right() {
	[ "$(top_row_count)" -ge 2 ]
}

has_bottom() {
	[ "$("$tmux_bin" list-panes -t "$window_target" -F '#{pane_top}' 2>/dev/null | awk 'NR == 1 { min = $1; max = $1 } $1 < min { min = $1 } $1 > max { max = $1 } END { if (max > min) print 1; else print 0 }')" -eq 1 ]
}

has_bottom_right() {
	has_bottom && [ "$(bottom_row_count)" -ge 2 ]
}

pane_path() {
	"$tmux_bin" display-message -p -t "$1" '#{pane_current_path}' 2>/dev/null || true
}

pane_command() {
	"$tmux_bin" display-message -p -t "$1" '#{pane_current_command}' 2>/dev/null || true
}

is_shell_pane() {
	case "$(pane_command "$1")" in
		bash|fish|sh|zsh) return 0 ;;
		*) return 1 ;;
	esac
}

ensure_top_right() {
	local top_left path
	has_top_right && return 0
	top_left="$(pick_pane top-left)"
	[ -z "$top_left" ] && return 0
	path="$(pane_path "$top_left")"
	if "$tmux_bin" split-window -h -d -t "$top_left" -c "${path:-$PWD}" >/dev/null 2>&1; then
		created_top_right=1
	fi
}

ensure_bottom() {
	local top_left path
	has_bottom && return 0
	top_left="$(pick_pane top-left)"
	[ -z "$top_left" ] && return 0
	path="$(pane_path "$top_left")"
	"$tmux_bin" split-window -v -d -t "$top_left" -c "${path:-$PWD}" >/dev/null 2>&1 || true
}

ensure_bottom_right() {
	local bottom path
	has_bottom_right && return 0
	ensure_bottom
	bottom="$(pick_pane bottom)"
	[ -z "$bottom" ] && return 0
	path="$(pane_path "$bottom")"
	"$tmux_bin" split-window -h -d -t "$bottom" -c "${path:-$PWD}" >/dev/null 2>&1 || true
}

ensure_role() {
	case "$role" in
		top-right) ensure_top_right ;;
		bottom) ensure_bottom ;;
		bottom-right) ensure_bottom_right ;;
		top-left) ;;
	esac
}

ensure_layout() {
	ensure_top_right
	ensure_bottom
	ensure_bottom_right
	"$tmux_bin" set-option -wq -t "$window_target" tiled-layout-max-columns 2 >/dev/null 2>&1 || true
	"$tmux_bin" select-layout -t "$window_target" tiled >/dev/null 2>&1 || true
}

launch_codex_if_needed() {
	local pane_id="$1"
	local launch_cmd
	[ "$role" = "top-right" ] || return 0
	[ "$created_top_right" -eq 1 ] || return 0
	printf -v launch_cmd '%q %q %q' "$HOME/.dotfiles/bin/tmux-supervise" "codex" "--dangerously-bypass-approvals-and-sandbox"
	"$tmux_bin" send-keys -t "$pane_id" -R "$launch_cmd" C-m >/dev/null 2>&1 || true
}

launch_layout_commands() {
	local top_left_pane top_right_pane

	top_left_pane="$(pick_pane top-left)"
	top_right_pane="$(pick_pane top-right)"

	if [ -n "$top_left_pane" ] && is_shell_pane "$top_left_pane"; then
		"$tmux_bin" send-keys -t "$top_left_pane" -R "vi ." C-m >/dev/null 2>&1 || true
	fi

	if [ -n "$top_right_pane" ] && is_shell_pane "$top_right_pane"; then
		"$tmux_bin" send-keys -t "$top_right_pane" -R "co" C-m >/dev/null 2>&1 || true
	fi
}

focus_only() {
	"$tmux_bin" select-pane -t "$1" >/dev/null 2>&1 || true
}

focus_and_zoom() {
	local pane_id="$1"
	"$tmux_bin" select-pane -t "$pane_id" >/dev/null 2>&1 || true
	"$tmux_bin" resize-pane -Z -t "$pane_id" >/dev/null 2>&1 || true
}

if [ "$mode" = "layout" ]; then
	if [ "$(window_zoomed_flag)" = "1" ]; then
		unzoom_window
	fi
	ensure_layout
	if [ "$layout_commands" != "no-commands" ]; then
		launch_layout_commands
	fi
	top_left_pane="$(pick_pane top-left)"
	[ -n "$top_left_pane" ] && focus_only "$top_left_pane"
	exit 0
fi

if [ "$mode" != "focus" ]; then
	if [ "$(window_zoomed_flag)" = "1" ]; then
		unzoom_window
	fi
	ensure_role
fi

pane_id="$(pick_pane "$role")"
[ -z "$pane_id" ] && exit 0
launch_codex_if_needed "$pane_id"

if [ "$mode" = "focus" ]; then
	focus_only "$pane_id"
else
	focus_and_zoom "$pane_id"
fi
