# Herdr

One job: preserve Herdr navigation and agent state.

## Execution host

- Default new coding work for all repositories to Ubuntu at
  `kylian@kylian-ps42-8rb`, using its persistent Herdr server. Keep the Mac Herdr
  interface for navigation, reading results, and returning to threads later.
- Keep existing conversations and work in place. Use Ubuntu for new delegated
  coding tasks; use the Mac for steps that need a Mac app or macOS runtime.
- In the new-thread picker, Ubuntu is selected by default. `Alt-m` selects Mac.
  `Cmd-o` retains the worktree picker.
- The quick-start shortcuts use Ubuntu for repos with an origin remote. On
  Ubuntu, they run locally. Explicit `herdr-start-codex mac` selects local Mac
  execution from the Mac; existing remote workspaces retain their checkout.
- Keep code transfer explicit through Git when a task needs a Mac step. Move
  committed work on the same branch, preserve dirty checkouts, and pass the
  relevant task context. Mac and Ubuntu agent conversations remain separate.
- SSH disconnection leaves Ubuntu's Herdr processes running. Ubuntu itself must
  remain powered on and awake. Never silently fall back to Mac when SSH fails.
- Use `sync-herdr-ubuntu --herdr-only` to deploy the portable launcher/picker
  changes without synchronizing Codex authentication, histories, or sessions.

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
