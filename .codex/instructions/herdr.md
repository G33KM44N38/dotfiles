# Herdr

One job: preserve Herdr navigation and agent state.

## Worktree picker

- Keep `Cmd-o` as the fast worktree picker.
- Include existing worktrees, local branches, and remote branches.
- Do not replace it with Herdr's native `open_worktree` action.
- The native action omits remote branches.

## Codex agents

- Launch programmatic Codex agents with `/Users/boss/.dotfiles/bin/herdr-run-codex-agent --task-name <name> -- <codex exec arguments...>`.
- Never launch a programmatic agent with raw `codex exec`.
- Launch interactive agents with Herdr 0.7.5 native `herdr agent start <unique-name> --kind codex --pane <pane-id> -- <codex arguments...>`.
- Publish the same unique name through pane metadata immediately after launch.

The wrapper gives Herdr a stable title and explicit working or idle state.
