#!/usr/bin/env swift

import Foundation
import EventKit

struct EventFeedback: Codable {
    let calendar: String
    let title: String
    let start: String
    let end: String
    let notes: String
}

struct Output: Codable {
    let query: String
    let count: Int
    let events: [EventFeedback]
}

struct Config {
    let query: String
    let calendarFilter: String?
    let daysBack: Int
    let daysForward: Int
    let limit: Int
}

func parseConfig() -> Config {
    let args = Array(CommandLine.arguments.dropFirst())
    var index = 0
    var queryParts: [String] = []
    var calendarFilter: String?
    var daysBack = 180
    var daysForward = 180
    var limit = 10

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
        case "--limit":
            limit = max(1, Int(takeValue()) ?? limit)
        case "--help", "-h":
            print("""
            Usage: fetch_calendar_feedback.swift [options] <query>

            Options:
              --calendar <name>      Filter by calendar name
              --days-back <n>        Search this many days back (default 180)
              --days-forward <n>     Search this many days forward (default 180)
              --limit <n>            Maximum results to return (default 10)
            """)
            exit(0)
        default:
            queryParts.append(arg)
        }
        index += 1
    }

    let query = queryParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
        fputs("Usage: fetch_calendar_feedback.swift [options] <query>\n", stderr)
        exit(1)
    }

    return Config(query: query, calendarFilter: calendarFilter, daysBack: daysBack, daysForward: daysForward, limit: limit)
}

func isoString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

func normalized(_ string: String) -> String {
    string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
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

let matches = events.compactMap { event -> EventFeedback? in
    let title = event.title ?? ""
    let notes = event.notes ?? ""
    let combined = normalized(title + "\n" + notes)
    guard combined.contains(queryNeedle) else { return nil }
    return EventFeedback(
        calendar: event.calendar.title,
        title: title,
        start: isoString(event.startDate),
        end: isoString(event.endDate),
        notes: notes.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ")
    )
}.sorted { $0.start < $1.start }

let limited = Array(matches.prefix(config.limit))
let output = Output(query: config.query, count: limited.count, events: limited)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

do {
    let data = try encoder.encode(output)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0a]))
} catch {
    fputs("Failed to encode output: \(error)\n", stderr)
    exit(1)
}
