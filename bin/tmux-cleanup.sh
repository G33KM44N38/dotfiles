#!/bin/bash
# tmux-cleanup.sh - terminate all processes in tmux panes
#
# Usage:
#   tmux-cleanup.sh pane <pane_pid> [pane_id]
#   tmux-cleanup.sh window <session> <window> [window...]
#   tmux-cleanup.sh session <session>
#   tmux-cleanup.sh server

set -euo pipefail

SIGTERM_TIMEOUT=${TMUX_CLEANUP_SIGTERM_TIMEOUT:-2}
TMUX_SUPERVISE_STATE_DIR=${TMUX_SUPERVISE_STATE_DIR:-/tmp}

wait_for_pid_exit() {
  local pid=$1
  local ticks=$2
  local waited=0

  while [ "$waited" -lt "$ticks" ]; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
    waited=$((waited + 1))
  done

  return 1
}

wait_for_group_exit() {
  local group_pid=$1
  local ticks=$2
  local waited=0

  while [ "$waited" -lt "$ticks" ]; do
    if ! pgrep -g "$group_pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
    waited=$((waited + 1))
  done

  return 1
}

build_process_tree() {
  local root_pid=$1
  local tree="$root_pid"
  local frontier="$root_pid"

  while [ -n "$frontier" ]; do
    local next_frontier=""
    for pid in $frontier; do
      local children
      children=$(pgrep -P "$pid" 2>/dev/null || true)
      [ -z "$children" ] && continue
      for child in $children; do
        case " $tree " in
          *" $child "*)
            ;;
          *)
            tree="$tree $child"
            next_frontier="$next_frontier $child"
            ;;
        esac
      done
    done
    frontier="$next_frontier"
  done

  printf '%s\n' "$tree"
}

wait_for_tree_exit() {
  local pid_list=$1
  local ticks=$2
  local waited=0

  while [ "$waited" -lt "$ticks" ]; do
    local any_alive=0
    for pid in $pid_list; do
      if kill -0 "$pid" >/dev/null 2>&1; then
        any_alive=1
        break
      fi
    done
    [ "$any_alive" -eq 0 ] && return 0
    sleep 0.1
    waited=$((waited + 1))
  done

  return 1
}

kill_tree_pids() {
  local signal=$1
  local pid_list=$2

  for pid in $pid_list; do
    kill "-$signal" "$pid" 2>/dev/null || true
  done
}

cleanup_supervised_group() {
  local pane_id=$1
  [ -z "$pane_id" ] && return 0

  local pane_key state_file child_pid
  pane_key=$(printf '%s' "${pane_id#%}" | tr -cd 'A-Za-z0-9._-')
  [ -z "$pane_key" ] && return 0

  state_file="${TMUX_SUPERVISE_STATE_DIR}/tmux-supervise-${pane_key}.pid"
  [ -f "$state_file" ] || return 0

  child_pid=$(tr -d '[:space:]' <"$state_file" 2>/dev/null || true)
  if [ -z "$child_pid" ]; then
    rm -f "$state_file" 2>/dev/null || true
    return 0
  fi
  if ! [[ "$child_pid" =~ ^[0-9]+$ ]] || [ "$child_pid" -le 1 ]; then
    rm -f "$state_file" 2>/dev/null || true
    return 0
  fi

  local process_tree
  process_tree=$(build_process_tree "$child_pid")
  if [ -n "$process_tree" ]; then
    kill_tree_pids TERM "$process_tree"
    if ! wait_for_tree_exit "$process_tree" 20; then
      kill_tree_pids KILL "$process_tree"
    fi
  fi

  rm -f "$state_file" 2>/dev/null || true
}

log_group_survivors() {
  local group_pid=$1
  local survivors
  survivors=$(pgrep -g "$group_pid" 2>/dev/null || true)
  [ -z "$survivors" ] && return 0

  echo "[tmux-cleanup] process group $group_pid still alive after SIGKILL" >&2
  for pid in $survivors; do
    local cmd
    cmd=$(ps -o args= -p "$pid" 2>/dev/null || true)
    [ -z "$cmd" ] && cmd="<unknown>"
    echo "[tmux-cleanup] pid=$pid cmd=$cmd" >&2
  done
}

kill_process_group() {
  local leader_pid=$1
  local pane_id=${2:-}
  [ -z "$leader_pid" ] && return 0
  if ! [[ "$leader_pid" =~ ^[0-9]+$ ]] || [ "$leader_pid" -le 1 ]; then
    return 0
  fi

  cleanup_supervised_group "$pane_id"

  local process_tree
  process_tree=$(build_process_tree "$leader_pid")
  [ -z "$process_tree" ] && return 0

  # Safety: kill only the pane process tree, not the whole process group.
  kill_tree_pids TERM "$process_tree"

  if wait_for_tree_exit "$process_tree" $((SIGTERM_TIMEOUT * 10)); then
    return 0
  fi

  kill_tree_pids KILL "$process_tree"

  if wait_for_tree_exit "$process_tree" 5; then
    return 0
  fi

  log_group_survivors "$leader_pid"
  return 0
}

cleanup_window() {
  local session=$1
  local window=$2
  local pane_entries
  pane_entries=$(tmux list-panes -t "${session}:${window}" -F "#{pane_id} #{pane_pid}" 2>/dev/null || true)

  [ -z "$pane_entries" ] && return 0

  while IFS= read -r pane_entry; do
    [ -z "$pane_entry" ] && continue
    local pane_id pane_pid
    pane_id=$(printf '%s\n' "$pane_entry" | awk '{print $1}')
    pane_pid=$(printf '%s\n' "$pane_entry" | awk '{print $2}')
    [ -z "$pane_pid" ] && continue
    kill_process_group "$pane_pid" "$pane_id"
  done <<< "$pane_entries"
}

cleanup_pane() {
  local pane_pid=$1
  local pane_id=${2:-}

  cleanup_supervised_group "$pane_id"
  [ -z "$pane_pid" ] && return 0

  kill_process_group "$pane_pid" "$pane_id"
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
    cleanup_pane "${2:-}" "${3:-}"
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
    echo "Usage: tmux-cleanup.sh pane <pane_pid> [pane_id] | window <session> <window> [window...] | session <session> | server" >&2
    exit 1
    ;;
esac
