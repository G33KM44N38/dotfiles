---
name: write-to-local-db
description: Write safe, targeted data into the BabaCoiffure local MongoDB for manual testing. Use when the user asks to seed, insert, backfill, or modify local DB records, especially users, chats, appointments, or fixture data in the BabaCoiffure monorepo local development database.
---

# Write To Local DB

Use this skill for local-only DB writes. Never use it for production, preprod, Render, Atlas, or remote DB writes unless the user explicitly says so and provides the exact connection target.

## Guardrails

- Confirm `git status --short --branch` before work; ignore unrelated file changes.
- Prefer targeted upserts/deletes by stable local seed keys (`uid`, email, explicit ObjectId).
- Do not write broad cleanup queries. Avoid `deleteMany({})`, collection drops, or destructive schema-wide changes.
- Print a concise readback after writes: target user, counts, changed records.
- Do not commit or push DB seed work unless separately asked.
- If Mongo is stopped, start only Mongo with `docker compose -f services/docker-compose.yml up -d mongodb`; do not run `pnpm dev`.

## Local Mongo

Default local URI from repo `.env`:

```txt
mongodb://localhost:27017/test?replicaSet=rs0&directConnection=true
```

Symptoms and fixes:

- `ECONNREFUSED ::1:27017, connect ECONNREFUSED 127.0.0.1:27017`: local Mongo is stopped. Start the `mongodb` compose service only.
- Replica set needed: the repo compose service initializes `rs0`; use `directConnection=true`.
- API model imports can be awkward under `tsx` stdin. Use `createRequire(import.meta.url)` for Mongoose model defaults.
- Import `./src/env-config` first when running from `apps/api` so `.env` loads.

## Workflow

1. Inspect schemas and calling code before writing:

```bash
rg -n "ModelName|fieldName" apps/api/src/database apps/api/src/router -g '*.ts'
```

2. Check Mongo availability:

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' | rg -i 'mongo|baba' || true
docker compose -f services/docker-compose.yml up -d mongodb
```

3. Run one scoped `tsx` script from `apps/api`; prefer stdin heredoc so shell does not expand Mongo operators like `$all` / `$size`.

```bash
pnpm --filter=@babacoiffure/api exec tsx <<'TS'
import './src/env-config'
import mongoose from 'mongoose'
import { createRequire } from 'module'

const require = createRequire(import.meta.url)
const User = require('./src/database/models/User').default

const uri =
    process.env.MONGODB_URI ||
    'mongodb://localhost:27017/test?replicaSet=rs0&directConnection=true'

await mongoose.connect(uri, { retryWrites: true })
const user = await User.findOne({ email: 'user@example.local' })
console.log('User:', user?._id?.toString() ?? 'not found')
await mongoose.disconnect()
TS
```

4. Validate by reading back the data with a second targeted query.

## Chat Seed Pattern

For chat UI testing, create correspondents with stable `uid`s, upsert chats by sorted two-user participant ids, replace only messages in those seeded chats, and set `lastMessageId` + `updatedAt`.

Important chat details:

- `Chat.userIds`: `ObjectId[]`, refs `User`.
- `Chat.lastMessageId`: ref `ChatMessage`.
- `ChatMessage` model file is `ChatMassage.ts`, model name is `ChatMessage`.
- `chat.list` returns only 10 chats and sorts by `updatedAt: -1`; set fresh `updatedAt` for seeded chats.
- Use enough messages per chat (for example 18) to test message-pane scrolling.

Minimal pattern:

```ts
const ids = [user._id, correspondent._id].map(id => String(id)).sort()
let chat = await Chat.findOne({ userIds: { $all: ids, $size: 2 } })
if (!chat) chat = await Chat.create({ userIds: ids })

await ChatMessage.deleteMany({ chatId: chat._id })
const inserted = await ChatMessage.insertMany(messages)
chat.lastMessageId = inserted[inserted.length - 1]._id
chat.updatedAt = new Date()
await chat.save()
```

