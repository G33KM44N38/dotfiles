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
- **Worktree**: git worktree managed/opened by Herdr, under the bare repository at `/Users/boss/coding/work/<repo>.git/<branch-slug>`.
- **Agent**: detected or started coding agent terminal, normally `codex`, named via `herdr agent start <name> ...`.
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

### Keep the same conversation in another worktree

When the active Codex conversation needs an isolated worktree, keep that same agent and conversation. Do not start a second agent merely because the work moves to another checkout.

1. Record the current workspace, checkout path, branch, and dirty state.
2. Never run `git switch`, `git checkout`, or an equivalent branch-changing command in the worktree that contains the active conversation or the user's original checkout.
3. Create or open the task worktree with `--no-focus`.
4. Keep the current Codex pane and conversation where they are. Run every task command and file operation against the task worktree's absolute path by setting the operation's working directory explicitly.
5. Verify the task worktree has the intended branch and the original worktree still has its original branch and dirty state.
6. Continue the task in the same conversation; report the task worktree path so the user can open it later if desired.

Start another agent only when the user explicitly asks to delegate, parallelize, or spin up an agent. Creating or opening a worktree alone is not an agent delegation request.

### Preserve user context

Background work must change neither the user's Herdr focus nor the branch checked out in their current worktree. Use `--no-focus` when creating or opening the target. Do not call `herdr workspace focus`, `herdr agent focus`, or `herdr agent attach` unless the user explicitly asks to switch, focus, open, or attach.

Create a Herdr-managed worktree from the current repo/workspace:

```bash
herdr worktree create --cwd "$PWD" --branch <branch-name> --label <label> --no-focus --json
```

The global Herdr `[worktrees].directory` setting owns placement. Do not pass
`--path` when creating a normal managed worktree; verify the returned path is
inside the source bare repository and never under `~/.herdr/worktrees`.

For BabaCoiffure bare repo, use:

```bash
herdr worktree create \
  --cwd /Users/boss/coding/work/babacoiffure_monorepo.git \
  --branch <branch-name> \
  --label <label> \
  --no-focus \
  --json
```

Open an existing worktree:

```bash
herdr worktree open --cwd "$PWD" --branch <branch-name> --label <label> --no-focus --json
herdr worktree open --cwd "$PWD" --path <worktree-path> --label <label> --no-focus --json
```

Create a plain workspace for a path:

```bash
herdr workspace create --cwd <path> --label <label> --no-focus
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

### BabaCoiffure workspace tab contract

When a workspace has standard tabs named `editor`, `agent`, `process`, and `terminal`, treat those tab names as a hard layout contract:

- `editor`: human/code editor only. Never start or send a coding agent here.
- `agent`: coding agents only. Always launch/delegate agent work here.
- `process`: long-running app/test processes.
- `terminal`: manual shell commands.

Before starting a delegated agent in an existing workspace:

1. Run `herdr tab list --workspace <workspace_id>`.
2. Find the tab labeled `agent`.
3. Select an idle pane in that tab, or create the agent pane inside it, without focusing the workspace.
4. Verify with `herdr pane list --workspace <workspace_id>` that the agent pane is in the `agent` tab, not `editor`.

Herdr 0.7.5 has no `agent start --workspace`, `--tab`, `--cwd`, or `--focus`
shortcut. Resolve the exact pane first so an agent can never land in `editor`.

Herdr 0.7.5 separates topology from agent launch. Create or select the exact
shell pane first, then start an interactive Codex with a unique meaningful
name (`[a-z][a-z0-9_-]{0,31}`):

```bash
herdr tab list --workspace <workspace_id>
herdr pane list --workspace <workspace_id>
herdr agent start <unique-task-name> \
  --kind codex \
  --pane <shell-pane-id> \
  -- --dangerously-bypass-approvals-and-sandbox
herdr pane report-metadata <shell-pane-id> \
  --source boss:codex-launch-title \
  --agent codex \
  --title <unique-task-name>
herdr agent prompt <shell-pane-id> "<task prompt>"
```

`herdr agent start` requires an existing idle shell pane; it does not create a
workspace, tab, pane, or worktree. Publish its initial name as launch metadata
immediately after start. The Codex SessionStart/title hook then keeps the human
pane title and Herdr-compatible agent name in accordance as the discussion is
resolved, including after `/new` and `/clear`. Because that display name can
change, use the pane ID as the stable target or refresh `herdr agent list`.

Only when non-interactive `codex exec` is technically required, run it through
the wrapper in an existing pane:

```bash
herdr pane run <shell-pane-id> \
  "/Users/boss/.dotfiles/bin/herdr-run-codex-agent --task-name '<task-name>' -- '<task prompt>'"
```

The wrapper contract is
`herdr-run-codex-agent [--task-name <name>] [--] <codex exec arguments...>`.
Prefer an explicit task name. When omitted, the wrapper derives a short title
from the positional prompt and falls back to the current project for stdin or
ambiguous invocations. Never launch raw `codex exec` in a Herdr pane.

If no workspace ID is known but the path is known, first create/open the workspace, inspect its tabs, then start in the `agent` tab. Do not guess.

Submit a prompt atomically with Herdr's agent-aware input handling:

```bash
herdr agent prompt <target> "<text>"
```

Focus or attach to an agent:

```bash
herdr agent focus <target>
herdr agent attach <target>
```

Wait for a status transition:

```bash
herdr agent wait <target> --until idle --timeout 600000
herdr agent wait <target> --until blocked --timeout 600000
```

## Common user intents

### “Create/use another worktree for this task”

1. Record the current workspace, checkout path, branch, and dirty state.
2. Use `herdr worktree create ... --no-focus --json` or `herdr worktree open ... --no-focus --json` from the relevant repo.
3. Extract and retain `workspace.workspace_id` and `worktree.path` from JSON.
4. Keep the current conversation. Run subsequent tools with their working directory set to `worktree.path`.
5. Verify the target branch and confirm the original checkout branch and Herdr focus did not change.
6. Report the target workspace, branch, and path.

### “Delegate X to another agent in a new worktree”

1. Record the currently focused workspace.
2. Create/open the worktree with `--no-focus --json`.
3. Resolve or create an idle pane in its `agent` tab without focusing it.
4. Start the named agent, publish its launch title, and submit `X` with `herdr agent prompt <pane-id>`.
5. Verify the new agent is active in the expected workspace/path and the original workspace remains focused.
6. Report workspace, branch, path, agent name, and status.

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
herdr agent prompt <target> "<message>"
```

Read recent output first if needed to avoid sending to the wrong agent.

## Safety rules

- Prefer JSON output (`--json`) when creating/listing worktrees so IDs and paths are exact.
- Preserve the active conversation, the user's current workspace focus, and the original worktree's branch. Use the target worktree path as the working directory instead of switching the original checkout.
- Never close workspaces, remove worktrees, kill panes, or overwrite agent state unless the user explicitly asks.
- Never use old tmux commands for thread/workspace management unless the user explicitly says tmux.
- When working from a bare repo, do not edit the bare repo directly. Create/open a Herdr worktree and work there.
- If the user says “thread” in a coding/work-session context, interpret it as a Herdr workspace/worktree/agent workflow.
