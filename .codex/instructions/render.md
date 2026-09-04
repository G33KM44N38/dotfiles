# Render

One job: keep Render CLI access safe and predictable.

## Rules

- Use `/Users/boss/.dotfiles/bin/render-oauth ...` for Render CLI operations.
- Start Render audits with `render-oauth whoami`.
- Use `render-credentials-check` to validate global keys.
- Do not let `RENDER_API_KEY` shadow the CLI OAuth session.
- Do not print secret file contents or matching secret values.
- Report only variable names and validation status.

The wrapper preserves global API-key exports for REST scripts while it protects the CLI OAuth session.
