---
name: ios-simulator-simslim
description: Use SimSlim by default for macOS iOS Simulator work, especially app runs and tests in linked Git worktrees that need a dedicated clone.
---

# iOS Simulator with SimSlim

Use a slim, isolated simulator without changing devices owned by other worktrees.

## Default workflow

1. Confirm the host is macOS and `simslim` is available.
2. Read the project configuration for its required device, runtime, and system features.
3. When the checkout is a linked Git worktree, use its dedicated clone.
4. For a normal checkout, use the simulator selected by the user or project.
5. Enable slim mode before the app run or test.
6. Pass the selected UDID to every build, install, launch, and test command.

Prefer an explicit source device. Otherwise, choose a compatible non-`WT-` iPhone with the newest supported runtime.

## Worktree clone

Use the bundled `scripts/worktree-simulator` helper from this skill directory.

```bash
scripts/worktree-simulator name
scripts/worktree-simulator find
scripts/worktree-simulator ensure <source-udid>
```

`ensure` reuses the exact clone name or creates it from the source. It prints only the clone UDID on success.

The name contains the repository, branch, and a path hash. This gives each linked worktree a stable, unique simulator.

Never use a clone whose `WT-` name belongs to another worktree. Prefer a base simulator, not another worktree clone, as the source.

Keep the clone after the task so later work can reuse it. Do not delete stale clones without an explicit request.

## Slim mode

For routine UI work, use the full slim profile:

```bash
simslim on <clone-udid>
```

Preserve features required by the task. Use `simslim profiles` to select the needed `--except` categories.

Common mappings include `store` for push or StoreKit, `web` for universal links, and `search` for Spotlight.

When the task states required features, check them after slimming:

```bash
simslim doctor <clone-udid> --requires push,storekit,universal-links
```

Use only the feature names that the task needs. If a system feature is unclear and material, ask before slimming.

SimSlim supports persistent slimming on iOS 18.5 or later. Use the normal simulator flow for older runtimes.

## Safety and isolation

- Treat the dedicated clone UDID as the worktree's simulator identity.
- Do not run app or test commands against the source after cloning.
- Do not change simulators assigned to other worktrees.
- Do not run `erase`, `delete`, `disk-clean`, or `repair-clone` unless the user requests that action.
- Do not restore stock mode after the task unless the user requests it or the test requires it.
- Use `simslim top` only when memory or parallel simulator health matters.

SimSlim manages simulator services. Continue to use the project's normal tools for builds, app installs, launches, and tests.
