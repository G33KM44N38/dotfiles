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

case "$role" in
	top-left|top-right|bottom) ;;
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
			}
			END { if (best_id != "") print best_id }
		'
}

top_row_count() {
	"$tmux_bin" list-panes -t "$window_target" -F '#{pane_top}' 2>/dev/null | \
		awk 'NR == 1 { min = $1 } $1 < min { min = $1 } { rows[NR] = $1 } END { c = 0; for (i in rows) if (rows[i] == min) c++; print c + 0 }'
}

has_top_right() {
	[ "$(top_row_count)" -ge 2 ]
}

has_bottom() {
	[ "$("$tmux_bin" list-panes -t "$window_target" -F '#{pane_top}' 2>/dev/null | awk 'NR == 1 { min = $1; max = $1 } $1 < min { min = $1 } $1 > max { max = $1 } END { if (max > min) print 1; else print 0 }')" -eq 1 ]
}

pane_path() {
	"$tmux_bin" display-message -p -t "$1" '#{pane_current_path}' 2>/dev/null || true
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

ensure_role() {
	case "$role" in
		top-right) ensure_top_right ;;
		bottom) ensure_bottom ;;
		top-left) ;;
	esac
}

launch_codex_if_needed() {
	local pane_id="$1"
	local launch_cmd
	[ "$role" = "top-right" ] || return 0
	[ "$created_top_right" -eq 1 ] || return 0
	printf -v launch_cmd '%q %q %q' "$HOME/.dotfiles/bin/tmux-supervise" "codex" "--dangerously-bypass-approvals-and-sandbox"
	"$tmux_bin" send-keys -t "$pane_id" -R "$launch_cmd" C-m >/dev/null 2>&1 || true
}

focus_only() {
	"$tmux_bin" select-pane -t "$1" >/dev/null 2>&1 || true
}

focus_and_zoom() {
	local pane_id="$1"
	local zoomed
	zoomed="$("$tmux_bin" display-message -p -t "$window_target" '#{window_zoomed_flag}' 2>/dev/null || true)"
	if [ "$zoomed" = "1" ]; then
		"$tmux_bin" select-pane -Z -t "$pane_id" >/dev/null 2>&1 || true
		return 0
	fi
	"$tmux_bin" select-pane -t "$pane_id" >/dev/null 2>&1 || true
	"$tmux_bin" resize-pane -Z -t "$pane_id" >/dev/null 2>&1 || true
}

if [ "$mode" != "focus" ]; then
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
