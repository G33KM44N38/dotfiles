---
name: read-whatsapp
description: Open and synchronize WhatsApp Desktop, read current local macOS chats, verify whether someone replied, and summarize messages, including voice-note transcription. Use when the user asks Codex to inspect a WhatsApp conversation, check for a recent response, find what someone said, understand a cancellation/request, search recent WhatsApp messages, or transcribe WhatsApp audio/voice notes.
---

# Read WhatsApp

Use this skill to inspect the user's local WhatsApp Desktop data on macOS. Default to read-only database queries and local transcription.

## Workflow

1. When the user asks whether someone replied or requests current/recent state, run the script with `--sync`. This opens WhatsApp and waits for the local database/WAL to refresh before reading.
2. Read the `WHATSAPP_SYNC` line. If it says `changed_and_settled`, treat the subsequent query as freshly synchronized. If it says `unchanged_after_wait`, report that WhatsApp was opened and allowed to sync but that no database change was observed; never state freshness as certain.
3. Locate the chat by name, phone/JID, or message text.
4. Pull recent messages with timestamps, sender direction, text, message type, and media paths.
5. Compare the newest incoming message with the newest outgoing message before concluding whether a reply exists.
6. When audio is present, convert it with `ffmpeg` and transcribe locally with `whisper-cli`.
7. Summarize only the relevant request. State transcript confidence if the model/audio is rough.

## Script

Prefer the bundled script:

```bash
python3 /Users/boss/.codex/skills/communication/read-whatsapp/scripts/read_whatsapp.py --chat "beautyhairmaiidi" --limit 80 --transcribe
```

Useful options:

```bash
python3 .../read_whatsapp.py --search "annuler" --limit 40
python3 .../read_whatsapp.py --chat "beautyhairmaiidi" --since "2026-06-06" --transcribe
python3 .../read_whatsapp.py --chat "beautyhairmaiidi" --transcribe --download-model
python3 .../read_whatsapp.py --chat "annaelle" --limit 40 --sync
```

Do not use a non-synchronized database read to assert that a recent reply does not exist merely because WhatsApp was closed. For status audits, include the sync result and the timestamp of the newest incoming/outgoing message.

## Local Transcription

Use local tools by default; no paid API.

- Convert audio: `ffmpeg -i input.opus -ar 16000 -ac 1 output.wav`
- Transcribe: `whisper-cli -m ~/.cache/whisper.cpp/ggml-tiny.bin -f output.wav -l fr -otxt`

If missing:

```bash
brew install whisper-cpp ffmpeg
mkdir -p ~/.cache/whisper.cpp
curl -L --fail -o ~/.cache/whisper.cpp/ggml-tiny.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin
```

Use larger models when exact wording matters; `tiny` is fast but approximate.

## Data Locations

Default DB:

```text
~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite
```

Default media root:

```text
~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message
```

Treat these as private user data. Do not inspect credentials. Do not modify WhatsApp files.
