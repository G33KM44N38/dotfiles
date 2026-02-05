#!/bin/bash
# tmux-cleanup.sh - terminate all processes in tmux panes
#
# Usage:
#   tmux-cleanup.sh pane <pane_pid>
#   tmux-cleanup.sh window <session> <window>
#   tmux-cleanup.sh session <session>
#   tmux-cleanup.sh server

set -euo pipefail

SIGTERM_TIMEOUT=2

collect_descendants() {
  local root_pid=$1
  local all_pids="$root_pid"
  local queue="$root_pid"

  while [ -n "$queue" ]; do
    local next_queue=""
    for pid in $queue; do
      local children
      children=$(ps -ax -o pid=,ppid= | awk -v parent="$pid" '$2 == parent {print $1}')
      if [ -n "$children" ]; then
        all_pids="$all_pids $children"
        next_queue="$next_queue $children"
      fi
    done
    queue="$next_queue"
  done

  echo "$all_pids"
}

kill_pids() {
  local pids=$1
  [ -z "$pids" ] && return 0

  for pid in $pids; do
    kill -TERM "$pid" 2>/dev/null || true
  done

  local waited=0
  while [ $waited -lt $((SIGTERM_TIMEOUT * 10)) ]; do
    local alive=0
    for pid in $pids; do
      if kill -0 "$pid" 2>/dev/null; then
        alive=1
        break
      fi
    done
    [ $alive -eq 0 ] && return 0
    sleep 0.1
    waited=$((waited + 1))
  done

  for pid in $pids; do
    kill -KILL "$pid" 2>/dev/null || true
  done
}

cleanup_window() {
  local session=$1
  local window=$2
  local pane_pids
  pane_pids=$(tmux list-panes -t "${session}:${window}" -F "#{pane_pid}" 2>/dev/null || true)

  [ -z "$pane_pids" ] && return 0

  local all_pids=""
  for pane_pid in $pane_pids; do
    [ -z "$pane_pid" ] && continue
    all_pids="$all_pids $(collect_descendants "$pane_pid")"
  done

  all_pids=$(echo "$all_pids" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  kill_pids "$all_pids"
}

cleanup_pane() {
  local pane_pid=$1
  [ -z "$pane_pid" ] && return 0

  local all_pids
  all_pids=$(collect_descendants "$pane_pid")
  all_pids=$(echo "$all_pids" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  kill_pids "$all_pids"
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
    cleanup_window "${2:-}" "${3:-}"
    ;;
  session)
    cleanup_session "${2:-}"
    ;;
  server)
    cleanup_server
    ;;
  *)
    echo "Usage: tmux-cleanup.sh pane <pane_pid> | window <session> <window> | session <session> | server" >&2
    exit 1
    ;;
esac
