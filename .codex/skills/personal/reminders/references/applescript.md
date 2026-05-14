# AppleScript Snippets

## Create In Named List

```bash
osascript <<'APPLESCRIPT'
set dueDate to date "Saturday, March 14, 2026 6:00:00 PM"

tell application "Reminders"
    set targetList to list "Personal"
    make new reminder at end of reminders of targetList with properties {name:"Call back", body:"Context", due date:dueDate}
end tell
APPLESCRIPT
```

## Mark Complete

```bash
osascript <<'APPLESCRIPT'
tell application "Reminders"
    tell default list
        set targetReminder to first reminder whose name is "Call back"
        set completed of targetReminder to true
    end tell
end tell
APPLESCRIPT
```

## Delete By Title

```bash
osascript <<'APPLESCRIPT'
tell application "Reminders"
    tell default list
        delete (every reminder whose name is "Call back")
    end tell
end tell
APPLESCRIPT
```

## Notes

- `body` maps to reminder notes.
- `due date` accepts an AppleScript date object.
- Some systems require first-run Automation permission for `osascript` -> `Reminders`.
