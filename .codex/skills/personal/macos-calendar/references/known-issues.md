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

## Transit route calculation fails

Symptom: `add-batch` reports that Apple Maps could not calculate a transit route, often with `MKErrorDomain error 5` internally.

Cause: MapKit directions from a command-line macOS process do not reliably return public-transit routes even when Calendar or Maps can display one.

Fix: Verify the transit duration in Maps or another routing source, then pass it as `travelMinutes`. Keep `travelFrom`, `location`, and `travelMode: "transit"` so Calendar still stores a native travel block with the correct endpoints and mode.

## Native travel fields stop saving after a macOS update

Symptom: The appointment saves but Calendar shows no travel block.

Cause: Apple does not expose all travel setters in EventKit's public Swift interface; the script uses the runtime setters that Calendar itself provides.

Fix: Run a temporary add/list/delete smoke test. Inspect the `EKEvent` runtime for `setTravelTime:`, `setTravelStartLocation:`, and `setTravelAdvisoryBehavior:` before updating the script. Never write directly to `Calendar.sqlitedb`.

## Large EventKit batch reports success but misses events

Symptom: `add-batch` reports that every requested event was added, but a subsequent `list` shows that part of a large batch is absent.

Cause: EventKit can commit only part of a large sequence of deferred saves without throwing an error.

Fix: The script now verifies every requested title/start pair after commit and fails loudly if any are absent. Rerun the exact same `add-batch` command; deduplication preserves existing events and adds only the missing ones. Always perform a final `list` or overlap audit after a large reorganization.
