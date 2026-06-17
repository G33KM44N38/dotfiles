---
name: send-whatsapp-jules
description: Draft and send WhatsApp messages to Jules from the user's macOS WhatsApp Desktop. Use when the user asks to message, notify, update, or send something to Jules on WhatsApp, especially for BabaCoiffure incident summaries; always draft the message first, apply the user's wording feedback, and send only after explicit confirmation.
---

# Send WhatsApp Jules

## Core Rule

Always show the exact message to the user before sending. Do not send until the user explicitly confirms with wording such as `envoie`, `ok envoie`, `send`, or equivalent.

## Message Style

- Write in French by default.
- Keep the message short, usually one sentence.
- For incident/status summaries, start by introducing that there was a problem.
- Be non-technical unless the user explicitly asks for technical detail.
- Avoid internal terms for Jules-facing messages: `OTA`, `channel`, `runtime`, `Sentry`, `bundle`, commit hashes, database ids.
- Prefer business-visible impact and outcome.

Example style:

```text
Il y avait un problème avec le compte BeautyHairMaidi: même avec l’application à jour, elle restait sur une ancienne version interne, ce qui l’empêchait de voir les dernières corrections comme l’annulation de rendez-vous; c’est corrigé maintenant.
```

## Workflow

1. Draft the message.
2. Present it clearly under `Message à envoyer à Jules :`.
3. Wait for user confirmation or edits.
4. After confirmation, run `scripts/send_jules_whatsapp.py --send --message "<message>"`.
5. Report whether the script opened WhatsApp and triggered send.

## Sending Script

Use:

```bash
python3 ~/.dotfiles/.codex/skills/send-whatsapp-jules/scripts/send_jules_whatsapp.py --message "..." --draft-only
python3 ~/.dotfiles/.codex/skills/send-whatsapp-jules/scripts/send_jules_whatsapp.py --message "..." --send
```

The script finds the WhatsApp chat whose display name is exactly `Jules`. It must not target contacts such as `Eva (jules)`. If the chat is missing or ambiguous, stop and ask the user.

Do not print Jules's phone number or WhatsApp JID in the final user-facing response.
