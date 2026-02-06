#!/bin/bash
# tmux-cleanup.sh - terminate all processes in tmux panes
#
# Usage:
#   tmux-cleanup.sh pane <pane_pid>
#   tmux-cleanup.sh window <session> <window> [window...]
#   tmux-cleanup.sh session <session>
#   tmux-cleanup.sh server

set -euo pipefail

SIGTERM_TIMEOUT=2

kill_process_group() {
  local leader_pid=$1
  [ -z "$leader_pid" ] && return 0

  # In tmux panes, pane_pid is typically the process-group leader.
  # Signaling the full group is much faster than walking the process tree.
  kill -TERM -- "-$leader_pid" 2>/dev/null || kill -TERM "$leader_pid" 2>/dev/null || true

  local waited=0
  while [ "$waited" -lt $((SIGTERM_TIMEOUT * 10)) ]; do
    if ! pgrep -g "$leader_pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
    waited=$((waited + 1))
  done

  kill -KILL -- "-$leader_pid" 2>/dev/null || kill -KILL "$leader_pid" 2>/dev/null || true
}

cleanup_window() {
  local session=$1
  local window=$2
  local pane_pids
  pane_pids=$(tmux list-panes -t "${session}:${window}" -F "#{pane_pid}" 2>/dev/null || true)

  [ -z "$pane_pids" ] && return 0

  for pane_pid in $pane_pids; do
    [ -z "$pane_pid" ] && continue
    kill_process_group "$pane_pid"
  done
}

cleanup_pane() {
  local pane_pid=$1
  [ -z "$pane_pid" ] && return 0

  kill_process_group "$pane_pid"
}

cleanup_session() {
  local session=$1
  local windows
  windows=$(tmux list-windows -t "$session" -F "#{window_index}" 2>/dev/null || true)

  [ -z "$windows" ] && return 0

  for window in $windows; do
    cleanup_window "$session" "$window"
  done
}

cleanup_server() {
  local sessions
  sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)

  [ -z "$sessions" ] && return 0

  for session in $sessions; do
    cleanup_session "$session"
  done
}

case "${1:-}" in
  pane)
    cleanup_pane "${2:-}"
    ;;
  window)
    session="${2:-}"
    shift 2 || true
    [ "$#" -eq 0 ] && exit 0
    for window in "$@"; do
      cleanup_window "$session" "$window"
    done
    ;;
  session)
    cleanup_session "${2:-}"
    ;;
  server)
    cleanup_server
    ;;
  *)
    echo "Usage: tmux-cleanup.sh pane <pane_pid> | window <session> <window> [window...] | session <session> | server" >&2
    exit 1
    ;;
esac
