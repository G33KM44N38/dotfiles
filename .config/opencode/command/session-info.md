# Session Info

Get detailed information about the current session and what was accomplished.

```bash
# Read session state files
session_file=".opencode/state/session.json"
shared_file=".opencode/state/shared.json"
task_queue_file=".opencode/state/workflow/task-queue.json"

echo "=== OpenCode Session Information ==="
echo ""

# Session details
if [ -f "$session_file" ]; then
    echo "📋 Session Status:"
    jq -r '
        if .feature and .feature != "feature-name-placeholder" then
            "  Feature: " + .feature
        else empty end,
        if .current_phase and .current_phase != "planning" then
            "  Phase: " + .current_phase
        else empty end,
        if .current_agent and .current_agent != "none" then
            "  Agent: " + .current_agent
        else empty end,
        if .summary and (.summary | length) > 0 then
            "  Summary: " + .summary
        else empty end
    ' "$session_file" 2>/dev/null | grep -v "null"
    echo ""
fi

# Task progress
if [ -f "$shared_file" ]; then
    echo "📊 Progress:"
    jq -r '
        if .task_progress then
            if .task_progress.total_tasks and (.task_progress.total_tasks > 0) then
                "  Tasks: " + (.task_progress.completed_tasks // 0 | tostring) + "/" + (.task_progress.total_tasks | tostring) + " completed"
            else empty end,
            if .task_progress.current_task and .task_progress.current_task != "Task description" then
                "  Current: " + .task_progress.current_task
            else empty end,
            if .task_progress.recent_completions and (.task_progress.recent_completions | length) > 0 then
                "  Last completed: " + .task_progress.recent_completions[-1]
            else empty end
        else empty end,
        if .files_modified and (.files_modified | length) > 0 then
            "  Modified " + (.files_modified | length | tostring) + " file(s)"
        else empty end,
        if .tests_run then
            "  Tests: " + (.tests_run.passed // 0 | tostring) + " passed, " + (.tests_run.failed // 0 | tostring) + " failed"
        else empty end
    ' "$shared_file" 2>/dev/null | grep -v "null"
    echo ""
fi

# Task queue
if [ -f "$task_queue_file" ]; then
    echo "📝 Task Queue:"
    jq -r '
        if . and (. | length) > 0 then
            .[] | "  - " + (.content // .description // "Unknown task") + " (" + (.status // "unknown") + ")"
        else
            "  No tasks in queue"
        end
    ' "$task_queue_file" 2>/dev/null
    echo ""
fi

# Recent messages count
if [ -f "$session_file" ]; then
    message_count=$(jq -r '.messages | length // 0' "$session_file" 2>/dev/null)
    echo "💬 Messages in session: $message_count"
    echo ""
fi

# Option to read summary aloud
echo "Would you like me to read the session summary aloud? (y/n)"
read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    summary="OpenCode session information: "
    
    if [ -f "$session_file" ]; then
        feature=$(jq -r '.feature // empty' "$session_file" 2>/dev/null)
        if [ -n "$feature" ] && [ "$feature" != "feature-name-placeholder" ]; then
            summary="$summary Feature $feature completed. "
        fi
    fi
    
    if [ -f "$shared_file" ]; then
        task_info=$(jq -r '
            if .task_progress.total_tasks and (.task_progress.total_tasks > 0) then
                (.task_progress.completed_tasks // 0 | tostring) + " of " + (.task_progress.total_tasks | tostring) + " tasks completed"
            else empty end
        ' "$shared_file" 2>/dev/null)
        
        if [ -n "$task_info" ]; then
            summary="$summary $task_info. "
        fi
    fi
    
    if [ ${#summary} -gt 30 ]; then
        say "$summary"
    else
        say "Session information displayed on screen"
    fi
fi
```