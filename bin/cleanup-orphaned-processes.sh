#!/bin/bash
# cleanup-orphaned-processes.sh - Clean up orphaned processes not in any tmux window
#
# Finds and gracefully terminates processes that:
# 1. Have PPID=1 (orphaned/reparented to init)
# 2. Are NOT currently running in any active tmux pane
# 3. Match specified process name patterns (opencode, claude, etc.)
#
# Usage:
#   cleanup-orphaned-processes.sh [process_pattern]
#   cleanup-orphaned-processes.sh           # defaults to "opencode"
#   cleanup-orphaned-processes.sh "claude"
#   cleanup-orphaned-processes.sh "opencode|claude"

set -euo pipefail

# Configuration
PROCESS_PATTERN="${1:-opencode}"  # Can be regex like "opencode|claude"
SIGTERM_TIMEOUT=2
DEBUG=${DEBUG:-0}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

debug_log() {
  if [ "$DEBUG" -eq 1 ]; then
    echo "[DEBUG] $*" >&2
  fi
}

log_info() {
  echo -e "${YELLOW}[info]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[ok]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[error]${NC} $*" >&2
}

# Get all PIDs that are descendants of tmux panes (processes we should NOT kill)
get_tmux_descendant_pids() {
  local tmux_pane_pids
  tmux_pane_pids=$(tmux list-panes -a -F "#{pane_pid}" 2>/dev/null || echo "")

  if [ -z "$tmux_pane_pids" ]; then
    echo ""
    return
  fi

  # For each tmux pane PID, collect all descendant PIDs recursively
  local all_descendants=""
  for pane_pid in $tmux_pane_pids; do
    [ -z "$pane_pid" ] && continue
    all_descendants="$all_descendants $pane_pid"
    # Recursively find all children using ps on macOS
    local children
    children=$(ps -ax -o pid=,ppid= | awk -v parent="$pane_pid" '$2 == parent {print $1}')
    for child in $children; do
      all_descendants="$all_descendants $child"
      # One more level deep (covers node -> opencode)
      local grandchildren
      grandchildren=$(ps -ax -o pid=,ppid= | awk -v parent="$child" '$2 == parent {print $1}')
      all_descendants="$all_descendants $grandchildren"
    done
  done

  echo "$all_descendants"
}

# Find all orphaned processes matching the pattern
find_orphaned_processes() {
  local pattern=$1

  # Get all PIDs that belong to tmux (should NOT be killed)
  local protected_pids
  protected_pids=$(get_tmux_descendant_pids)
  debug_log "Protected tmux PIDs: $protected_pids"

  # Find processes matching pattern with PPID=1 using proper ps columns
  # ps -ax -o pid=,ppid=,comm= gives us PID, PPID, COMMAND on macOS
  local orphaned_pids=""
  while IFS= read -r line; do
    local pid ppid comm
    pid=$(echo "$line" | awk '{print $1}')
    ppid=$(echo "$line" | awk '{print $2}')
    comm=$(echo "$line" | awk '{$1=$2=""; print $0}' | xargs)

    # Skip if not orphaned (PPID != 1)
    [ "$ppid" != "1" ] && continue

    # Skip if doesn't match our pattern
    echo "$comm" | grep -qE "$pattern" || continue

    # Skip if it's a protected tmux process
    local is_protected=0
    for protected_pid in $protected_pids; do
      if [ "$pid" = "$protected_pid" ]; then
        is_protected=1
        break
      fi
    done

    if [ "$is_protected" -eq 0 ]; then
      debug_log "Found orphaned: PID=$pid PPID=$ppid COMM=$comm"
      orphaned_pids="$orphaned_pids $pid"
    else
      debug_log "Skipping protected: PID=$pid PPID=$ppid COMM=$comm"
    fi
  done <<< "$(ps -ax -o pid=,ppid=,comm=)"

  echo "$orphaned_pids" | xargs
}

# Gracefully terminate a process
terminate_process() {
  local pid=$1

  if ! kill -0 "$pid" 2>/dev/null; then
    debug_log "Process $pid no longer exists"
    return 0
  fi

  # Get process name for logging
  local proc_name
  proc_name=$(ps -o comm= -p "$pid" 2>/dev/null | head -c 40 || echo "unknown")

  log_info "Terminating orphaned process (PID: $pid, $proc_name)"

  # Try SIGTERM first
  if kill -TERM "$pid" 2>/dev/null; then
    debug_log "Sent SIGTERM to PID $pid"

    # Wait for graceful shutdown (check every 100ms)
    local waited=0
    while [ $waited -lt $((SIGTERM_TIMEOUT * 10)) ]; do
      if ! kill -0 "$pid" 2>/dev/null; then
        log_success "Process $pid terminated gracefully"
        return 0
      fi
      sleep 0.1
      waited=$((waited + 1))
    done

    # Still running - use SIGKILL
    log_info "Process $pid didn't respond to SIGTERM, sending SIGKILL"
    kill -KILL "$pid" 2>/dev/null || true
    sleep 0.5
    if ! kill -0 "$pid" 2>/dev/null; then
      log_success "Process $pid terminated with SIGKILL"
      return 0
    fi
  fi

  log_error "Failed to terminate process $pid"
  return 1
}

# Main function
main() {
  debug_log "Searching for orphaned processes matching: $PROCESS_PATTERN"

  local orphaned_pids
  orphaned_pids=$(find_orphaned_processes "$PROCESS_PATTERN")

  if [ -z "$orphaned_pids" ]; then
    debug_log "No orphaned processes found"
    return 0
  fi

  log_info "Found orphaned processes: $orphaned_pids"

  local failed=0
  for pid in $orphaned_pids; do
    [ -z "$pid" ] && continue
    terminate_process "$pid" || failed=$((failed + 1))
  done

  if [ "$failed" -eq 0 ]; then
    log_success "All orphaned processes cleaned up"
    return 0
  else
    log_error "Failed to clean up $failed process(es)"
    return 1
  fi
}

main "$@"
