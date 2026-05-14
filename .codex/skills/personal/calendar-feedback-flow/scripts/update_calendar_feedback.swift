#!/usr/bin/env swift

import Foundation
import EventKit

struct Config {
    let query: String
    let calendarFilter: String?
    let daysBack: Int
    let daysForward: Int
    let appendText: String
    let dryRun: Bool
}

func parseConfig() -> Config {
    let args = Array(CommandLine.arguments.dropFirst())
    var index = 0
    var queryParts: [String] = []
    var calendarFilter: String?
    var daysBack = 180
    var daysForward = 180
    var appendText = ""
    var dryRun = false

    func takeValue() -> String {
        let valueIndex = index + 1
        guard valueIndex < args.count else {
            fputs("Missing value for option.\n", stderr)
            exit(1)
        }
        index = valueIndex
        return args[valueIndex]
    }

    while index < args.count {
        let arg = args[index]
        switch arg {
        case "--calendar":
            calendarFilter = takeValue()
        case "--days-back":
            daysBack = Int(takeValue()) ?? daysBack
        case "--days-forward":
            daysForward = Int(takeValue()) ?? daysForward
        case "--append-text":
            appendText = takeValue()
        case "--dry-run":
            dryRun = true
        case "--help", "-h":
            print("""
            Usage: update_calendar_feedback.swift [options] <query>

            Options:
              --calendar <name>      Filter by calendar name
              --days-back <n>        Search this many days back (default 180)
              --days-forward <n>     Search this many days forward (default 180)
              --append-text <text>   Text block to append to the matched event notes
              --dry-run              Print the target event and exit
            """)
            exit(0)
        default:
            queryParts.append(arg)
        }
        index += 1
    }

    let query = queryParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
        fputs("Usage: update_calendar_feedback.swift [options] <query>\n", stderr)
        exit(1)
    }

    guard !appendText.isEmpty || dryRun else {
        fputs("Provide --append-text or --dry-run.\n", stderr)
        exit(1)
    }

    return Config(query: query, calendarFilter: calendarFilter, daysBack: daysBack, daysForward: daysForward, appendText: appendText, dryRun: dryRun)
}

func normalized(_ string: String) -> String {
    string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
}

func trimmedBlock(_ text: String) -> String {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

let config = parseConfig()
let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
var granted = false
var authError: Error?

if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents { ok, err in
        granted = ok
        authError = err
        semaphore.signal()
    }
} else {
    store.requestAccess(to: .event) { ok, err in
        granted = ok
        authError = err
        semaphore.signal()
    }
}

_ = semaphore.wait(timeout: .now() + 10)

if let authError {
    fputs("Calendar access error: \(authError)\n", stderr)
}

guard granted else {
    fputs("Calendar access not granted.\n", stderr)
    exit(1)
}

let now = Date()
let calendar = Calendar.current
guard let start = calendar.date(byAdding: .day, value: -config.daysBack, to: now),
      let end = calendar.date(byAdding: .day, value: config.daysForward, to: now) else {
    fputs("Failed to build date range.\n", stderr)
    exit(1)
}

let queryNeedle = normalized(config.query)
let calendarNeedle = config.calendarFilter.map(normalized)

let calendars = store.calendars(for: .event).filter { cal in
    guard let calendarNeedle else { return true }
    return normalized(cal.title).contains(calendarNeedle)
}

let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
let events = store.events(matching: predicate)

let matches = events.filter { event in
    let title = event.title ?? ""
    let notes = event.notes ?? ""
    let combined = normalized(title + "\n" + notes)
    return combined.contains(queryNeedle)
}.sorted { $0.startDate < $1.startDate }

guard let event = matches.first else {
    fputs("No matching event found.\n", stderr)
    exit(1)
}

if config.dryRun {
    print("CALENDAR=\(event.calendar.title)")
    print("TITLE=\(event.title ?? "")")
    print("START=\(event.startDate)")
    print("END=\(event.endDate)")
    print("NOTES=\(event.notes ?? "")")
    exit(0)
}

let existingNotes = event.notes ?? ""
let block = trimmedBlock(config.appendText)
let separator = existingNotes.isEmpty ? "" : "\n\n"
let mergedNotes = existingNotes + separator + block

event.notes = mergedNotes

do {
    try store.save(event, span: .thisEvent)
    print("Updated event notes for: \(event.title ?? "")")
} catch {
    fputs("Failed to save event: \(error)\n", stderr)
    exit(1)
}
