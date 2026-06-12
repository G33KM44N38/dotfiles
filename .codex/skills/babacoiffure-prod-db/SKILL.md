---
name: babacoiffure-prod-db
description: Find, inspect, and safely verify the BabaCoiffure production MongoDB connection from the user's local Neovim dadbod config and shell environment. Use when the user asks for the production database, prod DB connection, MongoDB Atlas access, dadbod database config, or to verify read-only production DB connectivity for BabaCoiffure.
---

# BabaCoiffure Prod DB

## Workflow

Use local config only. Do not use web search.

1. Read dadbod config:
   `/Users/boss/.config/nvim/lua/root/plugins/dadbod.lua`
2. Confirm the prod entry:
   `babacoiffure_production`
3. Build URI from env vars, never print secrets:
   `BABACOIFFURE_DB_USERNAME`
   `BABACOIFFURE_DB_PASSWORD`
4. Use this host/db shape:
   `mongodb+srv://<user>:<password>@cluster0.k2k9ux7.mongodb.net/production?retryWrites=true&w=majority&appName=Cluster0`
5. Verify with read-only commands only unless the user explicitly asks for a write.

## Safety

- Never echo username, password, full URI, query results containing PII, tokens, emails, phones, addresses, payment data, or auth fields.
- Report credentials as `set/missing` and optionally length only.
- Prefer metadata checks: `ping`, `db.getName()`, `db.getCollectionNames()`.
- For document reads, use tight projections and limits.
- Ask before any production write, delete, migration, index change, or bulk operation.

## Quick Verify

Run:

```bash
/Users/boss/.codex/skills/babacoiffure-prod-db/scripts/check-production-db.sh
```

Expected output shape:

```text
BABACOIFFURE_DB_USERNAME=set len=...
BABACOIFFURE_DB_PASSWORD=set len=...
mongosh=...
ping=1
db=production
collections=...
```

## Manual Commands

Use this pattern if the script needs adjustment:

```bash
bash -lc 'uri=$(python3 - <<'"'"'PY'"'"'
import os, urllib.parse
u = os.environ.get("BABACOIFFURE_DB_USERNAME")
p = os.environ.get("BABACOIFFURE_DB_PASSWORD")
if not u or not p:
    raise SystemExit("missing credentials")
print(f"mongodb+srv://{urllib.parse.quote(u)}:{urllib.parse.quote(p)}@cluster0.k2k9ux7.mongodb.net/production?retryWrites=true&w=majority&appName=Cluster0")
PY
); mongosh "$uri" --quiet --eval "JSON.stringify({ ping: db.runCommand({ ping: 1 }).ok, db: db.getName(), collections: db.getCollectionNames().slice(0, 20) })"'
```

If `mongosh` connects to `127.0.0.1:27017`, the URI was not passed as an argument.
