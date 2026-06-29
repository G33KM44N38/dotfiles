---
name: tmux-thread-picker
description: Inspect, create, duplicate, kill, and navigate the user's tmux work threads through the tmux-thread-picker CLI. Use whenever the user says "thread" or "threads" in a Codex/tmux/work-session context, including active tmux sessions, LLM/Codex threads, running or waiting agent work, switching to a thread, creating another thread for the current path, killing a thread, sending input to a tmux pane, creating/opening git worktree threads, or understanding what work is happening across tmux.
---

# Tmux Thread Picker

Use the user's thread picker as the source of truth for tmux work threads and LLM/Codex activity.

## Commands

Inspect threads:

```bash
/Users/boss/.dotfiles/bin/tmux-thread-picker.sh --rows
```

Use the explicit tmux socket for navigation and pane control:

```bash
tmux -S /private/tmp/tmux-501/default switch-client -t 'session:window'
tmux -S /private/tmp/tmux-501/default select-pane -t '%pane'
tmux -S /private/tmp/tmux-501/default send-keys -t '%pane' 'text' Enter
```

Open the interactive picker only when the user wants direct interactive selection:

```bash
/Users/boss/.dotfiles/bin/tmux-thread-picker.sh
```

The interactive UI is implemented in Go with Bubble Tea. It is not `fzf`-based; live state refresh happens inside the picker and should not be controlled through `fzf` reload/listen behavior.

The user's tmux bindings open the interactive picker in a full-screen borderless tmux popup:

```tmux
M-t  display-popup -B -E -w 100% -h 100% ... TMUX_THREAD_ATTENTION_ONLY=1 ... tmux-thread-picker.sh
M-T  display-popup -B -E -w 100% -h 100% ... TMUX_THREAD_ATTENTION_ONLY=0 ... tmux-thread-picker.sh
```

Create another 4-pane thread window for the same path, intentionally bypassing worktree deduplication:

```bash
/Users/boss/.dotfiles/bin/tmux-worktree-layout.sh duplicate '<source-session>' '<path>' '[name]'
```

Use this for requests like "create another session thread for the current path" or "make two more of these". Prefer the current tmux session as `<source-session>` and the current working directory as `<path>`. This command must leave the user on the current tmux window after creating the duplicate thread.

## Row Format

`--rows` prints tab-separated rows:

```text
kind    visible_display    target    branch    pin_key    project    search_text
```

Relevant `kind` values:

- `GROUP`: project heading; never navigate to this.
- `OPEN`: existing tmux window or Codex pane; navigate with `target`.
- `WT`: git worktree not currently open; opening it may create/switch tmux layout through the picker workflow.

For `OPEN`, `target` is usually `session:window`. When a row represents a specific pane it can include a pane suffix; switch to the window first, then select the pane if present.

## State Labels

Read these from the visible display column:

- `run` or `▶`: Codex/LLM work is actively running.
- `wait` or `●`: Codex/LLM work finished and is waiting for user attention.
- `codex`: a Codex CLI pane is open but not marked running.
- `open*`: current tmux window.
- `open`: existing tmux window.
- `work`: available git worktree.
- `!`: busy process in that window.
- `P`: pinned thread.
- `A`: archived thread.

Prefer summarizing `run`, `wait`, `codex`, and `!` rows first when the user asks what needs attention.

## Safe Workflow

1. Run `tmux-thread-picker.sh --rows`.
2. Parse only the row fields needed for the task.
3. For status questions, report project, title, state, path/branch, and duration if visible.
4. For navigation requests, use `tmux switch-client` with the row target, and `select-pane` when the target identifies a pane.
5. For sending text, select the pane only when needed, then use `send-keys`.

Never kill tmux windows or panes unless the user explicitly asks to close/kill them. Do not use picker keybindings like `ctrl-q` on the user's behalf unless explicitly requested.

For duplicate same-path thread creation, do not use raw `tmux new-window`; it only creates one pane. Call `tmux-worktree-layout.sh duplicate ...` so the result gets the standard 4-pane layout and preserves the user's current window.

## Useful Filters

Show all rows even when an attention-only environment is active:

```bash
TMUX_THREAD_ATTENTION_ONLY=0 /Users/boss/.dotfiles/bin/tmux-thread-picker.sh --rows
```

Show archived rows:

```bash
TMUX_THREAD_SHOW_ARCHIVED=1 /Users/boss/.dotfiles/bin/tmux-thread-picker.sh --rows
```

Use `--list` for a human-readable list without row metadata:

```bash
/Users/boss/.dotfiles/bin/tmux-thread-picker.sh --list
```

## Interactive Picker Keys

When the user is driving the UI:

- `Enter`: open selected thread.
- `Ctrl-n`: create a new thread worktree.
- `Ctrl-r`: refresh.
- `Ctrl-o`: open the worktree selector.
- `Ctrl-p`: pin or unpin.
- `Ctrl-t`: edit title.
- `Ctrl-y`: regenerate auto-title.
- `Ctrl-x` or `Alt-a`: archive or unarchive.
- `Alt-f`: show all.
- `Alt-v`: show archived.
