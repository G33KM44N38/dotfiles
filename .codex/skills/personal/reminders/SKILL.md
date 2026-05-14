---
name: reminders
description: Manage Apple Reminders from Codex. Use when the user asks to create, update, complete, delete, or list reminders/tasks in Apple Reminders on this Mac, including "remind me", "make a reminder", "due today", or "show my reminders".
---

# Reminders

Use this skill for Apple Reminders tasks on macOS.

## Quick Check

1. Confirm macOS context: `uname` should be `Darwin`.
2. For relative dates like `today` or `tomorrow`, resolve first with `date` and use exact dates in the reply if useful.
3. Assume default list unless user names a specific list.

## Workflow

1. Translate the request into reminder fields:
- `name`: short action title
- `body`: optional long notes/source message/link
- `due date`: explicit date/time if given; otherwise choose a sensible same-day time only when the user asked for "today"
- `list`: default list unless specified

2. Create/update via `osascript`:
- Create reminder in default list:
```bash
osascript <<'APPLESCRIPT'
set dueDate to current date
set hours of dueDate to 18
set minutes of dueDate to 0
set seconds of dueDate to 0

tell application "Reminders"
    set targetList to default list
    make new reminder at end of reminders of targetList with properties {name:"Review app", body:"Notes here", due date:dueDate}
end tell
APPLESCRIPT
```
- Read/list reminders:
```bash
osascript <<'APPLESCRIPT'
tell application "Reminders"
    tell default list
        get name of reminders
    end tell
end tell
APPLESCRIPT
```

3. Verify command result:
- If `osascript` hangs, poll once; macOS may be waiting on Automation permission.
- If it succeeds, reply with title, due date, and target list.
- If blocked by permissions, say that directly.

## Rules

- Keep reminder titles concise; move long text into `body`.
- Preserve URLs in the note body.
- Do not invent a date if the user did not ask for one.
- For "today", prefer a clear local due time like `18:00` if none supplied.
- Use exact dates in the confirmation when the user used relative wording.

## Reference

- For more AppleScript snippets, read `references/applescript.md`.
