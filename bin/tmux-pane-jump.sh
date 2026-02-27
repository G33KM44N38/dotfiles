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

target="${1:-top-left}"
window_target="${2:-}"
if [ -z "$window_target" ]; then
	window_target="$("$tmux_bin" display-message -p '#{window_id}' 2>/dev/null || true)"
fi

pane_rows=""
if [ -n "$window_target" ]; then
	pane_rows="$("$tmux_bin" list-panes -t "$window_target" -F '#{pane_id}\t#{pane_top}\t#{pane_left}' 2>/dev/null || true)"
fi
if [ -z "$pane_rows" ]; then
	pane_rows="$("$tmux_bin" list-panes -F '#{pane_id}\t#{pane_top}\t#{pane_left}' 2>/dev/null || true)"
fi
[ -z "$pane_rows" ] && exit 0

pane_id="$(
	printf '%s\n' "$pane_rows" | \
	awk -F'\t' -v mode="$target" '
		BEGIN {
			best_id = ""
			best_top = -1
			best_left = -1
		}
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

			if (mode == "top-left") {
				if (top < best_top || (top == best_top && left < best_left)) {
					best_id = id
					best_top = top
					best_left = left
				}
				next
			}

			if (mode == "top-right") {
				if (top < best_top || (top == best_top && left > best_left)) {
					best_id = id
					best_top = top
					best_left = left
				}
				next
			}

			if (mode == "bottom") {
				if (top > best_top || (top == best_top && left < best_left)) {
					best_id = id
					best_top = top
					best_left = left
				}
				next
			}
		}
		END {
			if (best_id != "") {
				print best_id
			}
		}
	'
)"

[ -z "$pane_id" ] && exit 0
"$tmux_bin" select-pane -t "$pane_id" >/dev/null 2>&1 || exit 0
