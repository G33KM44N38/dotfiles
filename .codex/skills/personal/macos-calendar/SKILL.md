---
name: macos-calendar
description: "Work with Apple Calendar on macOS from Codex: inspect, add, update, import, deduplicate, and delete local/iCloud calendar events using EventKit, AppleScript, .ics files, or Computer Use. Use when the user asks to put dates in their calendar, modify event times, remove duplicates/all-day events, troubleshoot Calendar permissions, or recover from Calendar automation failures."
---

# macOS Calendar

## Core Workflow

Prefer the bundled EventKit script before AppleScript for reads, writes, and cleanup:

```bash
swift "$CODEX_HOME/skills/macos-calendar/scripts/calendar_tool.swift" list --from 2026-06-20 --to 2026-07-13 --title-contains "CAN de Paris"
```

Use AppleScript only for simple UI-app checks or when EventKit is unavailable. Use Computer Use for Calendar/System Settings dialogs, visible confirmations, and final destructive UI actions.

## Safety

- Confirm before deleting calendar events through a GUI action.
- For script deletions, scope by date range, calendar name when known, and title/location/notes. List matching events before deletion when the user has not already described the exact target.
- Never delete broad matches like every event in a calendar.
- Preserve user-created unrelated events and calendars.

## EventKit Script

Run:

```bash
swift "$CODEX_HOME/skills/macos-calendar/scripts/calendar_tool.swift" <command> [options]
```

Commands:

- `list --from YYYY-MM-DD --to YYYY-MM-DD [--calendar NAME] [--title-contains TEXT]`
- `delete-all-day --from YYYY-MM-DD --to YYYY-MM-DD [--calendar NAME] --title-contains TEXT`
- `add-batch --calendar NAME --file events.json`

For `add-batch`, create JSON like:

```json
[
  {
    "title": "Match de poule - CAN de Paris",
    "start": "2026-06-24T18:00:00",
    "end": "2026-06-24T20:00:00",
    "timeZone": "Europe/Paris",
    "notes": "Tournoi CAN de Paris"
  }
]
```

The script deduplicates adds by title and start time within the target calendar.

## Permissions

If EventKit says access is not granted:

1. Open `x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars`.
2. Ask the user to grant the relevant app/process Full Access to Calendars.
3. Retry the EventKit command.

Common entries:

- `Codex`: needed when the command runs from Codex.
- `Ghostty` or `Terminal`: needed when the command runs from a shell app.
- `node`: may appear when browser or Node-based tooling touched Calendar.

If Calendar automation hangs, kill only stuck automation processes:

```bash
pkill -f '^osascript' || true
```

Then retry with EventKit.

## .ics Fallback

Use `.ics` import when EventKit cannot write but Calendar UI can import. Include `TZID=Europe/Paris` for local French times. After opening an `.ics`, Calendar may ask for a destination calendar; select the user-requested calendar before confirming.

Remember that clicking `OK` in Calendar creates events, so follow Computer Use confirmation policy when required.

## Self-Improvement

When this skill hits a new Calendar-specific failure and the fix is reusable:

1. Add a concise entry to [known-issues.md](references/known-issues.md).
2. Patch `scripts/calendar_tool.swift` if a deterministic guard or command would prevent recurrence.
3. Run `quick_validate.py` on the skill.
4. Mention the skill update in the final answer.

Keep updates narrow: record the symptom, likely cause, and the exact command or workflow that fixed it.
