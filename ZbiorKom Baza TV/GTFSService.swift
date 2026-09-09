//
//  GTFSService.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//


import Foundation
import ZIPFoundation
import Combine


enum GTFSKind: String, CaseIterable, Sendable {
    case tram = "T"
    case bus = "A"

    var title: String {
        self == .tram ? "Tramwaje" : "Autobusy"
    }

    var fileName: String {
        "GTFS_KRK_\(rawValue).zip"
    }

    var folderName: String {
        "GTFS-\(rawValue)"
    }
}

struct GTFSStop: Identifiable, Hashable, Sendable {
    let id: String
    let rawID: String
    let kind: GTFSKind
    let code: String
    let name: String
}

struct GTFSGroup: Identifiable, Sendable {
    let id: String
    let name: String
    let stops: [GTFSStop]
}

struct GTFSDeparture: Identifiable, Sendable {
    let id: String
    let line: String
    let destination: String
    let date: Date
    let kind: GTFSKind
    let stopCode: String
}

enum GTFSDataError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

// MARK: - CSV

private enum GTFSCSV {
    typealias Row = [String: String]

    static func read(
        _ url: URL,
        consume: (Row) -> Void
    ) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let characters = Array(text.unicodeScalars)

        var header: [String]?
        var row: [String] = []
        var field = ""
        var quoted = false
        var index = 0

        func emit() {
            row.append(field)
            field = ""

            guard row.contains(where: { !$0.isEmpty }) else {
                row = []
                return
            }

            if header == nil {
                header = row.map {
                    $0.replacingOccurrences(of: "\u{FEFF}", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if let header {
                var record: Row = [:]

                for (key, value) in zip(header, row) {
                    record[key] = value
                }

                consume(record)
            }

            row = []
        }

        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                if quoted,
                   index + 1 < characters.count,
                   characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    quoted.toggle()
                }

            } else if character == "," && !quoted {
                row.append(field)
                field = ""

            } else if (character == "\n" || character == "\r") && !quoted {
                if character == "\r",
                   index + 1 < characters.count,
                   characters[index + 1] == "\n" {
                    index += 1
                }

                emit()

            } else {
                field.unicodeScalars.append(character)
            }

            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            emit()
        }
    }
}

// MARK: - Internal models

private struct TripInfo: Sendable {
    let routeID: String
    let serviceID: String
    let headsign: String
}

private struct StopTime: Sendable {
    let tripID: String
    let seconds: Int
    let sequence: String
    let headsign: String
}

private struct ServiceCalendar: Sendable {
    let start: String
    let end: String
    let weekdays: [Bool]
}

private struct FeedData: Sendable {
    let kind: GTFSKind
    var stops: [GTFSStop] = []
    var routes: [String: String] = [:]
    var trips: [String: TripInfo] = [:]
    var stopTimes: [String: [StopTime]] = [:]
    var calendars: [String: ServiceCalendar] = [:]
    var exceptions: [String: [String: Bool]] = [:]

    static func load(from directory: URL, kind: GTFSKind) throws -> FeedData {
        var feed = FeedData(kind: kind)

        func file(_ name: String) -> URL {
            directory.appendingPathComponent(name)
        }

        try GTFSCSV.read(file("stops.txt")) { row in
            guard let id = row["stop_id"],
                  let name = row["stop_name"] else { return }

            feed.stops.append(
                GTFSStop(
                    id: "\(kind.rawValue):\(id)",
                    rawID: id,
                    kind: kind,
                    code: row["stop_code"] ?? "",
                    name: name
                )
            )
        }

        try GTFSCSV.read(file("routes.txt")) { row in
            guard let id = row["route_id"],
                  let name = row["route_short_name"] else { return }

            feed.routes[id] = name
        }

        try GTFSCSV.read(file("trips.txt")) { row in
            guard let id = row["trip_id"],
                  let route = row["route_id"],
                  let service = row["service_id"] else { return }

            feed.trips[id] = TripInfo(
                routeID: route,
                serviceID: service,
                headsign: row["trip_headsign"] ?? ""
            )
        }

        try GTFSCSV.read(file("stop_times.txt")) { row in
            guard let stopID = row["stop_id"],
                  let tripID = row["trip_id"],
                  let time = row["departure_time"],
                  let seconds = parseTime(time) else { return }

            // 1 = brak możliwości wsiadania.
            guard row["pickup_type"] != "1" else { return }

            feed.stopTimes[stopID, default: []].append(
                StopTime(
                    tripID: tripID,
                    seconds: seconds,
                    sequence: row["stop_sequence"] ?? "",
                    headsign: row["stop_headsign"] ?? ""
                )
            )
        }

        try GTFSCSV.read(file("calendar.txt")) { row in
            guard let id = row["service_id"],
                  let start = row["start_date"],
                  let end = row["end_date"] else { return }

            let weekdays = [
                "monday", "tuesday", "wednesday", "thursday",
                "friday", "saturday", "sunday"
            ].map { row[$0] == "1" }

            feed.calendars[id] = ServiceCalendar(
                start: start,
                end: end,
                weekdays: weekdays
            )
        }

        try GTFSCSV.read(file("calendar_dates.txt")) { row in
            guard let id = row["service_id"],
                  let date = row["date"] else { return }

            feed.exceptions[id, default: [:]][date] =
                row["exception_type"] == "1"
        }

        guard !feed.stops.isEmpty,
              !feed.routes.isEmpty,
              !feed.trips.isEmpty,
              !feed.stopTimes.isEmpty else {
            throw GTFSDataError.message(
                "Paczka \(kind.title) nie zawiera poprawnych danych."
            )
        }

        print("GTFS \(kind.title): \(feed.stops.count) przystanków")
        return feed
    }

    private static func parseTime(_ text: String) -> Int? {
        let parts = text.split(separator: ":").compactMap { Int($0) }

        guard parts.count == 3 else { return nil }

        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }
}

// MARK: - Service

actor GTFSService {
    private var feeds: [GTFSKind: FeedData] = [:]

    private let zone = TimeZone(identifier: "Europe/Warsaw")!

    private var root: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("KrakowDepartures", isDirectory: true)
    }

    func availableKinds() -> [GTFSKind] {
        GTFSKind.allCases.filter { feeds[$0] != nil }
    }

    func loadCached() -> [String] {
        var errors: [String] = []

        for kind in GTFSKind.allCases {
            let directory = root.appendingPathComponent(kind.folderName)

            guard FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("stops.txt").path
            ) else { continue }

            do {
                feeds[kind] = try FeedData.load(
                    from: directory,
                    kind: kind
                )
            } catch {
                errors.append("\(kind.title): \(error.localizedDescription)")
            }
        }

        return errors
    }

    func download(_ kind: GTFSKind) async throws {
        let url = URL(
            string: "https://gtfs.ztp.krakow.pl/\(kind.fileName)"
        )!

        let (temporaryURL, response) = try await URLSession.shared.download(
            from: url
        )

        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            throw GTFSDataError.message(
                "Serwer nie zwrócił poprawnej odpowiedzi dla \(kind.title)."
            )
        }

        let fm = FileManager.default
        try fm.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        let staging = root.appendingPathComponent(
            "download-\(UUID().uuidString)",
            isDirectory: true
        )

        let contents = staging.appendingPathComponent(
            "contents",
            isDirectory: true
        )

        try fm.createDirectory(
            at: contents,
            withIntermediateDirectories: true
        )

        defer {
            try? fm.removeItem(at: staging)
        }

        let zipURL = staging.appendingPathComponent(kind.fileName)
        try fm.moveItem(at: temporaryURL, to: zipURL)

        try fm.unzipItem(at: zipURL, to: contents)

        let required = [
            "stops.txt", "routes.txt", "trips.txt",
            "stop_times.txt", "calendar.txt", "calendar_dates.txt"
        ]

        for name in required {
            guard fm.fileExists(
                atPath: contents.appendingPathComponent(name).path
            ) else {
                throw GTFSDataError.message("W ZIP brakuje \(name).")
            }
        }

        // Najpierw sprawdzamy nową paczkę.
        let parsed = try FeedData.load(from: contents, kind: kind)

        let destination = root.appendingPathComponent(kind.folderName)
        let backup = staging.appendingPathComponent("backup")
        let hadOld = fm.fileExists(atPath: destination.path)

        if hadOld {
            try fm.moveItem(at: destination, to: backup)
        }

        do {
            try fm.moveItem(at: contents, to: destination)
        } catch {
            if hadOld {
                try? fm.moveItem(at: backup, to: destination)
            }
            throw error
        }

        feeds[kind] = parsed
    }

    // MARK: - Unified stops

    func groups() -> [GTFSGroup] {
        var grouped: [String: [GTFSStop]] = [:]

        for feed in feeds.values {
            for stop in feed.stops {
                let key = Self.normalized(stop.name)
                grouped[key, default: []].append(stop)
            }
        }

        return grouped.map { key, stops in
            GTFSGroup(
                id: key,
                name: stops[0].name,
                stops: stops.sorted { $0.code < $1.code }
            )
        }
        .sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pl_PL")
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Departures

    func departures(
        for stops: [GTFSStop],
        now: Date,
        limit: Int = 12
    ) -> [GTFSDeparture] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        let today = calendar.startOfDay(for: now)
        var result: [GTFSDeparture] = []

        for stop in stops {
            guard let feed = feeds[stop.kind],
                  let times = feed.stopTimes[stop.rawID] else { continue }

            for offset in -1...1 {
                guard let serviceDay = calendar.date(
                    byAdding: .day,
                    value: offset,
                    to: today
                ) else { continue }

                let dateKey = Self.dateKey(serviceDay, calendar: calendar)

                for time in times {
                    guard let trip = feed.trips[time.tripID],
                          let line = feed.routes[trip.routeID],
                          serviceRuns(
                            trip.serviceID,
                            on: serviceDay,
                            feed: feed,
                            calendar: calendar
                          ),
                          let departureDate = departureDate(
                            serviceDay: serviceDay,
                            seconds: time.seconds,
                            calendar: calendar
                          ) else { continue }

                    guard departureDate >= now,
                          departureDate <= now.addingTimeInterval(24 * 3600)
                    else { continue }

                    result.append(
                        GTFSDeparture(
                            id: "\(stop.kind.rawValue):\(dateKey):\(time.tripID):\(time.sequence):\(stop.rawID)",
                            line: line,
                            destination: time.headsign.isEmpty
                                ? trip.headsign
                                : time.headsign,
                            date: departureDate,
                            kind: stop.kind,
                            stopCode: stop.code
                        )
                    )
                }
            }
        }

        return Array(
            result.sorted { $0.date < $1.date }.prefix(limit)
        )
    }

    private func serviceRuns(
        _ id: String,
        on date: Date,
        feed: FeedData,
        calendar: Calendar
    ) -> Bool {
        let key = Self.dateKey(date, calendar: calendar)

        if let exception = feed.exceptions[id]?[key] {
            return exception
        }

        guard let service = feed.calendars[id],
              key >= service.start,
              key <= service.end else {
            return false
        }

        let weekday = calendar.component(.weekday, from: date)
        let index = (weekday + 5) % 7

        return service.weekdays[index]
    }

    private static func dateKey(
        _ date: Date,
        calendar: Calendar
    ) -> String {
        let parts = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )

        return String(
            format: "%04d%02d%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    private func departureDate(
        serviceDay: Date,
        seconds: Int,
        calendar: Calendar
    ) -> Date? {
        let extraDays = seconds / 86_400
        let remainder = seconds % 86_400

        guard let day = calendar.date(
            byAdding: .day,
            value: extraDays,
            to: serviceDay
        ) else { return nil }

        var parts = calendar.dateComponents(
            [.year, .month, .day],
            from: day
        )

        parts.hour = remainder / 3600
        parts.minute = (remainder % 3600) / 60
        parts.second = remainder % 60
        parts.timeZone = zone

        return calendar.date(from: parts)
    }
}

