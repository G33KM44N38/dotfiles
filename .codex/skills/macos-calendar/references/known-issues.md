# Known Issues

## EventKit access denied

Symptom: Swift/EventKit prints `Calendar access was not granted.`

Cause: macOS privacy permissions are per app/process. Codex may have Add Only Access or no Calendar access even when Calendar.app itself works.

Fix: Open `x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars` and ask the user to grant Full Access to the process running the command, usually Codex, Ghostty, or Terminal.

## AppleScript Calendar hangs

Symptom: `osascript` commands targeting Calendar keep running without output.

Likely causes: Calendar is waiting on sync, a dialog, or a slow cloud account.

Fix: Prefer EventKit. If a stuck script remains, run `pkill -f '^osascript' || true`, then retry with the EventKit script.

## Imported all-day duplicates

Symptom: Events appear both at `00:00-23:59` and at the requested time.

Fix: Run `delete-all-day` scoped by date range and title text, then `list` to confirm `allDay=0` and expected timed events remain.
