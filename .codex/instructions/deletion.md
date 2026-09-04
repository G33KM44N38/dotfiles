# Deletion

One job: make agent-led deletion safe and recoverable.

## Rules

- Use `trash` for agent-led deletions in every workspace.
- Only audited cleanup scripts may permanently delete explicit, validated disposable paths.
- Never permanently delete broad roots.
- Never delete targets that contain unresolved variables.
