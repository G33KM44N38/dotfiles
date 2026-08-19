---
name: read-babacoiffure-instagram
description: Read and summarize BabaCoiffure Instagram Business DM conversations through the configured Instagram Graph API token. Use when the user asks to check, find, inspect, read, or summarize messages or conversations received by @babacoiffure, including a conversation with a named person or Instagram handle.
---

# Read BabaCoiffure Instagram

Use the bundled script for deterministic, read-only Instagram Graph API access.
Never source `.env` in a shell: dotenv values may contain shell metacharacters.

## Workflow

1. State that the operation is read-only.
2. Verify the configured account:

   ```bash
   node /Users/boss/.dotfiles/.codex/skills/babacoiffure/read-babacoiffure-instagram/scripts/read-instagram-dm.mjs account
   ```

3. Find the conversation by handle or name:

   ```bash
   node /Users/boss/.dotfiles/.codex/skills/babacoiffure/read-babacoiffure-instagram/scripts/read-instagram-dm.mjs conversations --search kaya
   ```

4. Read message metadata first. Add `--include-text` only when the user explicitly asks to read or summarize message contents:

   ```bash
   node /Users/boss/.dotfiles/.codex/skills/babacoiffure/read-babacoiffure-instagram/scripts/read-instagram-dm.mjs messages --username kaya.haven --limit 20
   node /Users/boss/.dotfiles/.codex/skills/babacoiffure/read-babacoiffure-instagram/scripts/read-instagram-dm.mjs messages --username kaya.haven --limit 20 --include-text
   ```

5. Summarize naturally. Distinguish messages sent by `babacoiffure` from messages received from the participant. Convert timestamps to the user's timezone when useful.

## Environment resolution

The script resolves credentials in this order:

1. `--env /absolute/path/.env` when explicitly requested
2. Doppler scope from `--doppler-project` + `--doppler-config`
3. Doppler scope from `BABACOIFFURE_DOPPLER_PROJECT` + `BABACOIFFURE_DOPPLER_CONFIG`
4. current Doppler project/config, or automatic discovery across accessible scopes
5. `BABACOIFFURE_INSTAGRAM_ENV_FILE`
6. nearest parent `.env` containing `INSTAGRAM_DM_ACCESS_TOKEN`
7. canonical BabaCoiffure `release-` or `main-` worktree `.env`

Doppler is authoritative by default. The script retrieves only the Instagram keys through the CLI, keeps values in memory, and never emits them. The `account` result reports only the safe credential source (`doppler:project/config`, `explicit-env`, or `env-fallback`). If Doppler authentication lacks access to the Instagram scope, report that access limitation and use the fallback only when it is configured and valid.

Required keys:

- `INSTAGRAM_GRAPH_API_BASE_URL`
- `INSTAGRAM_GRAPH_API_VERSION`
- `INSTAGRAM_DM_ACCESS_TOKEN`

`INSTAGRAM_BUSINESS_ACCOUNT_ID` is optional for verification. `INSTAGRAM_DM_SYNC_ENABLED=false` disables automatic synchronization only; it does not block an explicit manual read.

## Safety

- Never print, return, copy, log, or store the access token.
- Never place the token in a URL or command argument; the script uses an authorization header.
- Never expose pagination URLs because Meta may embed credentials in them.
- Never send, delete, react to, mark, or otherwise mutate a message with this skill.
- Never ask the user to paste a token into chat. Ask them to renew the value in `.env` when authentication fails.
- Keep message content out of commentary/tool summaries unless the user requested the content.
- Treat conversation contents as private. Return only what is needed for the request.

## Error handling

- Report only the sanitized Meta error type, code, and message.
- If the configured API version is rejected, verify the current endpoint using official Meta documentation only.
- If several conversations match, show handles and update times, then use the exact handle requested by the user.
- If no conversation matches, paginate before concluding it is absent.

## Script reference

```text
read-instagram-dm.mjs account [--doppler-project NAME --doppler-config NAME] [--env PATH]
read-instagram-dm.mjs conversations [--search TEXT] [--limit 1-100] [--pages 1-20] [--doppler-project NAME --doppler-config NAME] [--env PATH]
read-instagram-dm.mjs messages (--username HANDLE | --conversation-id ID) [--limit 1-100] [--include-text] [--doppler-project NAME --doppler-config NAME] [--env PATH]
```

The script emits sanitized JSON for reliable downstream parsing. Conversation IDs may be returned because they identify records, but omit them from the user-facing answer unless technically useful.
