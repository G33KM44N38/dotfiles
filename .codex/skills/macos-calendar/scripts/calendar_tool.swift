import EventKit
import Foundation

struct BatchEvent: Decodable {
    let title: String
    let start: String
    let end: String
    let timeZone: String?
    let notes: String?
    let location: String?
}

func fail(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(1)
}

func value(after flag: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func parseDay(_ value: String, endOfDay: Bool = false) -> Date {
    let parts = value.split(separator: "-").map(String.init)
    guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
        fail("Invalid date: \(value). Use YYYY-MM-DD.")
    }
    var c = DateComponents()
    c.calendar = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone.current
    c.year = y
    c.month = m
    c.day = d
    c.hour = endOfDay ? 23 : 0
    c.minute = endOfDay ? 59 : 0
    c.second = endOfDay ? 59 : 0
    guard let date = c.date else { fail("Invalid date: \(value)") }
    return date
}

func parseLocalDateTime(_ value: String, timeZone: TimeZone) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    guard let date = formatter.date(from: value) else {
        fail("Invalid datetime: \(value). Use YYYY-MM-DDTHH:MM:SS.")
    }
    return date
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    fail("Usage: calendar_tool.swift <list|delete-all-day|add-batch> [options]")
}

let store = EKEventStore()
let sem = DispatchSemaphore(value: 0)
var granted = false

if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents { ok, error in
        if let error { fputs("Calendar access error: \(error)\n", stderr) }
        granted = ok
        sem.signal()
    }
} else {
    store.requestAccess(to: .event) { ok, error in
        if let error { fputs("Calendar access error: \(error)\n", stderr) }
        granted = ok
        sem.signal()
    }
}

sem.wait()
guard granted else {
    fail("Calendar access was not granted. Grant Full Access in System Settings > Privacy & Security > Calendars.")
}

func calendars(named name: String?) -> [EKCalendar] {
    guard let name else { return store.calendars(for: .event) }
    let matches = store.calendars(for: .event).filter { $0.title == name }
    guard !matches.isEmpty else { fail("No calendar named '\(name)' found.") }
    return matches
}

func isAllDayLike(_ event: EKEvent) -> Bool {
    let cal = Calendar(identifier: .gregorian)
    let parts = cal.dateComponents([.hour, .minute], from: event.startDate)
    let duration = event.endDate.timeIntervalSince(event.startDate)
    return event.isAllDay || (parts.hour == 0 && parts.minute == 0 && duration >= 23 * 60 * 60)
}

switch command {
case "list":
    guard let fromText = value(after: "--from", in: args), let toText = value(after: "--to", in: args) else {
        fail("list requires --from YYYY-MM-DD --to YYYY-MM-DD")
    }
    let titleContains = value(after: "--title-contains", in: args)
    let cals = calendars(named: value(after: "--calendar", in: args))
    let events = store.events(matching: store.predicateForEvents(withStart: parseDay(fromText), end: parseDay(toText, endOfDay: true), calendars: cals))
        .filter { titleContains == nil || $0.title.localizedCaseInsensitiveContains(titleContains!) }
        .sorted { $0.startDate < $1.startDate }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    for event in events {
        print("\(formatter.string(from: event.startDate)) | \(formatter.string(from: event.endDate)) | allDay=\(event.isAllDay) | \(event.calendar.title) | \(event.title ?? "")")
    }
    print("SUMMARY total=\(events.count) allDayLike=\(events.filter(isAllDayLike).count)")

case "delete-all-day":
    guard let fromText = value(after: "--from", in: args), let toText = value(after: "--to", in: args), let titleContains = value(after: "--title-contains", in: args) else {
        fail("delete-all-day requires --from YYYY-MM-DD --to YYYY-MM-DD --title-contains TEXT")
    }
    let cals = calendars(named: value(after: "--calendar", in: args))
    let events = store.events(matching: store.predicateForEvents(withStart: parseDay(fromText), end: parseDay(toText, endOfDay: true), calendars: cals))
        .filter { $0.title.localizedCaseInsensitiveContains(titleContains) && isAllDayLike($0) }
    for event in events {
        try store.remove(event, span: .thisEvent, commit: false)
    }
    try store.commit()
    print("Removed \(events.count) all-day-like event(s).")

case "add-batch":
    guard let calendarName = value(after: "--calendar", in: args), let file = value(after: "--file", in: args) else {
        fail("add-batch requires --calendar NAME --file events.json")
    }
    guard let targetCalendar = calendars(named: calendarName).first else { fail("No calendar named '\(calendarName)' found.") }
    let data = try Data(contentsOf: URL(fileURLWithPath: file))
    let batch = try JSONDecoder().decode([BatchEvent].self, from: data)
    var added = 0
    for item in batch {
        let tz = TimeZone(identifier: item.timeZone ?? TimeZone.current.identifier) ?? TimeZone.current
        let start = parseLocalDateTime(item.start, timeZone: tz)
        let end = parseLocalDateTime(item.end, timeZone: tz)
        let existing = store.events(matching: store.predicateForEvents(withStart: start.addingTimeInterval(-60), end: end.addingTimeInterval(60), calendars: [targetCalendar]))
            .contains { $0.title == item.title && abs($0.startDate.timeIntervalSince(start)) < 60 }
        if existing { continue }
        let event = EKEvent(eventStore: store)
        event.title = item.title
        event.calendar = targetCalendar
        event.startDate = start
        event.endDate = end
        event.notes = item.notes
        event.location = item.location
        try store.save(event, span: .thisEvent, commit: false)
        added += 1
    }
    try store.commit()
    print("Added \(added) event(s).")

default:
    fail("Unknown command: \(command)")
}
