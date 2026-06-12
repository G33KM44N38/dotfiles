---
name: read-whatsapp
description: Read local macOS WhatsApp chats and summarize user requests, including voice-note transcription. Use when the user asks Codex to inspect a WhatsApp conversation, find what someone said, understand a cancellation/request, search recent WhatsApp messages, or transcribe WhatsApp audio/voice notes from the local WhatsApp database/media folder.
---

# Read WhatsApp

Use this skill to inspect the user's local WhatsApp Desktop data on macOS. Default to read-only database queries and local transcription.

## Workflow

1. Locate the chat by name, phone/JID, or message text.
2. Pull recent messages with timestamps, sender direction, text, message type, and media paths.
3. When audio is present, convert it with `ffmpeg` and transcribe locally with `whisper-cli`.
4. Summarize only the relevant request. State transcript confidence if the model/audio is rough.

## Script

Prefer the bundled script:

```bash
python3 /Users/boss/.codex/skills/read-whatsapp/scripts/read_whatsapp.py --chat "beautyhairmaiidi" --limit 80 --transcribe
```

Useful options:

```bash
python3 .../read_whatsapp.py --search "annuler" --limit 40
python3 .../read_whatsapp.py --chat "beautyhairmaiidi" --since "2026-06-06" --transcribe
python3 .../read_whatsapp.py --chat "beautyhairmaiidi" --transcribe --download-model
```

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
