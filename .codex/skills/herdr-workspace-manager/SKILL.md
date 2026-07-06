---
name: herdr-workspace-manager
description: Manage the user's coding workspaces, threads, worktrees, tabs, panes, and running AI agents through Herdr. Use whenever the user says thread, threads, workspace, worktree, tab, pane, agent, switch, focus, open a workspace, create a worktree, start an agent, send input to an agent, check what is running/waiting, or asks to migrate old tmux thread workflows. Prefer this over tmux unless the user explicitly asks for tmux.
---

# Herdr Workspace Manager

Use `herdr` as the source of truth for the user's coding workspaces, git worktrees, tabs, panes, and AI-agent activity.

Herdr replaces the user's old tmux thread workflow. Do not use tmux/thread-picker commands unless the user explicitly asks for tmux.

## Documentation and discovery

Primary CLI docs are available from the installed binary:

```bash
herdr --help
herdr workspace --help
herdr worktree --help
herdr agent --help
herdr pane --help
herdr tab --help
herdr wait --help
herdr session --help
```

Runtime paths:

```text
Config: /Users/boss/.config/herdr/config.toml
Logs:   /Users/boss/.config/herdr/herdr.log
Home:   https://herdr.dev
```

If a subcommand fails or behavior is unclear, read the relevant `--help` before improvising.

## Core concepts

- **Workspace**: top-level Herdr work area. Often linked to a repo/worktree.
- **Worktree**: git worktree managed/opened by Herdr, usually under `/Users/boss/.herdr/worktrees/<repo>/<branch-slug>`.
- **Agent**: detected or started coding agent terminal, e.g. `pi`, `codex`, named via `herdr agent start <name> ...`.
- **Tab/pane**: terminal layout units inside a workspace.

Use workspace IDs (`wX`) and terminal/pane IDs from JSON output. Avoid guessing IDs.

## Inspect state

List workspaces:

```bash
herdr workspace list
```

List agents and status:

```bash
herdr agent list
```

List worktrees for the current/repo path:

```bash
herdr worktree list --cwd "$PWD" --json
```

For a bare repo or known repo root, pass that path explicitly:

```bash
herdr worktree list --cwd /Users/boss/coding/work/babacoiffure_monorepo.git --json
```

Read an agent's visible/recent output:

```bash
herdr agent read <target> --source recent --lines 80 --format text
herdr agent read <target> --source visible --lines 80 --format text
```

Explain target resolution:

```bash
herdr agent explain <target> --json
```

## Create/open worktrees and workspaces

Create a Herdr-managed worktree from the current repo/workspace:

```bash
herdr worktree create --cwd "$PWD" --branch <branch-name> --label <label> --focus --json
```

For BabaCoiffure bare repo, use:

```bash
herdr worktree create \
  --cwd /Users/boss/coding/work/babacoiffure_monorepo.git \
  --branch <branch-name> \
  --label <label> \
  --focus \
  --json
```

Open an existing worktree:

```bash
herdr worktree open --cwd "$PWD" --branch <branch-name> --label <label> --focus --json
herdr worktree open --cwd "$PWD" --path <worktree-path> --label <label> --focus --json
```

Create a plain workspace for a path:

```bash
herdr workspace create --cwd <path> --label <label> --focus
```

Focus or rename a workspace:

```bash
herdr workspace focus <workspace_id>
herdr workspace rename <workspace_id> <label>
```

Close/remove only on explicit user request:

```bash
herdr workspace close <workspace_id>
herdr worktree remove --workspace <workspace_id> --force --json
```

## Start and control agents

Start a named agent in a workspace/worktree:

```bash
herdr agent start <agent-name> \
  --workspace <workspace_id> \
  --cwd <path> \
  --focus \
  -- pi "<task prompt>"
```

If no workspace ID is known but the path is known:

```bash
herdr agent start <agent-name> --cwd <path> --focus -- pi "<task prompt>"
```

Send text to an agent without pressing Enter semantics beyond Herdr's literal send behavior:

```bash
herdr agent send <target> "<text>"
```

Focus or attach to an agent:

```bash
herdr agent focus <target>
herdr agent attach <target>
```

Wait for a status transition:

```bash
herdr agent wait <target> --status idle --timeout 600000
herdr agent wait <target> --status blocked --timeout 600000
```

## Common user intents

### “Create a new thread/workspace/worktree and make an agent work on X”

1. Use `herdr worktree create ... --json` from the relevant repo.
2. Extract `workspace.workspace_id` and `worktree.path` from JSON.
3. Start an agent in that workspace/path with `herdr agent start ... -- pi "X"`.
4. Report workspace label, branch, path, and agent name.

### “What is running / waiting / needs attention?”

1. Run `herdr agent list` and `herdr workspace list`.
2. Summarize agents with `working`, `blocked`, `idle`, or `unknown` status.
3. For ambiguous/important agents, read recent output with `herdr agent read`.

### “Switch/focus/open that thread”

Use Herdr focus commands, not tmux:

```bash
herdr workspace focus <workspace_id>
herdr agent focus <target>
```

### “Send this to the agent”

Use:

```bash
herdr agent send <target> "<message>"
```

Read recent output first if needed to avoid sending to the wrong agent.

## Safety rules

- Prefer JSON output (`--json`) when creating/listing worktrees so IDs and paths are exact.
- Never close workspaces, remove worktrees, kill panes, or overwrite agent state unless the user explicitly asks.
- Never use old tmux commands for thread/workspace management unless the user explicitly says tmux.
- When working from a bare repo, do not edit the bare repo directly. Create/open a Herdr worktree and work there.
- If the user says “thread” in a coding/work-session context, interpret it as a Herdr workspace/worktree/agent workflow.
