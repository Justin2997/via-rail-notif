import Foundation
import ZIPFoundation

enum ViaDataError: LocalizedError {
    case invalid(String), outsideHorizon, tooLarge, http(Int)
    var errorDescription: String? {
        switch self {
        case .invalid(let detail): "Données VIA invalides : \(detail)."
        case .outsideHorizon: "Date hors de la période couverte par les horaires VIA."
        case .tooLarge: "Le fichier VIA dépasse la taille autorisée."
        case .http(let status): "Source VIA indisponible (HTTP \(status))."
        }
    }
}

enum ViaTime {
    static func day(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
            throw ViaDataError.invalid("date de service")
        }
        return date
    }

    static func instant(_ value: String?, zone: String? = nil) -> Date? {
        guard let value, value.range(of:
            #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"#,
            options: .regularExpression) != nil else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var parsed = formatter.date(from: value)
        if parsed == nil {
            formatter.formatOptions = [.withInternetDateTime]
            parsed = formatter.date(from: value)
        }
        guard let parsed else { return nil }
        if let zone {
            guard let timeZone = TimeZone(identifier: zone) else { return nil }
            var offset = 0
            if !value.hasSuffix("Z") {
                let suffix = String(value.suffix(6))
                let components = suffix.dropFirst().split(separator: ":").compactMap { Int($0) }
                guard components.count == 2, components[0] < 24, components[1] < 60 else { return nil }
                offset = (components[0] * 3600 + components[1] * 60) * (suffix.first == "-" ? -1 : 1)
            }
            guard timeZone.secondsFromGMT(for: parsed) == offset else { return nil }
        }
        return parsed
    }

    static func gtfs(day: String, clock: String, zone: String) throws -> Date {
        _ = try self.day(day)
        guard let timeZone = TimeZone(identifier: zone) else {
            throw ViaDataError.invalid("fuseau GTFS")
        }
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3, (0...240).contains(parts[0]),
              (0..<60).contains(parts[1]), (0..<60).contains(parts[2]) else {
            throw ViaDataError.invalid("heure GTFS")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let noon = formatter.date(from: day + " 12:00:00") else {
            throw ViaDataError.invalid("date GTFS")
        }
        return noon.addingTimeInterval(Double((parts[0] - 12) * 3600 + parts[1] * 60 + parts[2]))
    }

    static func iso(_ value: Date) -> String { ISO8601DateFormatter().string(from: value) }
}

enum CSV {
    // UTF-8 parser supporting BOM, quoted commas, escaped quotes and embedded CR/LF.
    static func rows(_ data: Data) throws -> [[String: String]] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ViaDataError.invalid("encodage CSV")
        }
        let bytes = Array(text.trimmingPrefix("\u{FEFF}").utf8)
        var rows: [[String]] = [], row: [String] = [], field: [UInt8] = []
        var quoted = false, closed = false, index = 0
        func value() -> String { String(decoding: field, as: UTF8.self) }
        while index < bytes.count {
            let byte = bytes[index]
            if quoted {
                if byte == 34 {
                    if index + 1 < bytes.count && bytes[index + 1] == 34 {
                        field.append(34); index += 1
                    } else { quoted = false; closed = true }
                } else { field.append(byte) }
            } else if byte == 44 || byte == 10 || byte == 13 {
                row.append(value()); field.removeAll(keepingCapacity: true); closed = false
                if byte != 44 {
                    if row != [""] { rows.append(row) }
                    row.removeAll(keepingCapacity: true)
                    if byte == 13 && index + 1 < bytes.count && bytes[index + 1] == 10 { index += 1 }
                }
            } else if byte == 34 && field.isEmpty && !closed {
                quoted = true
            } else {
                guard !closed && byte != 34 else { throw ViaDataError.invalid("guillemets CSV") }
                field.append(byte)
            }
            index += 1
        }
        guard !quoted else { throw ViaDataError.invalid("guillemets CSV non fermés") }
        if !row.isEmpty || !field.isEmpty || closed { row.append(value()); rows.append(row) }
        guard let header = rows.first, Set(header).count == header.count,
              !header.contains("") else { throw ViaDataError.invalid("en-tête CSV") }
        return try rows.dropFirst().map { row in
            guard row.count == header.count else { throw ViaDataError.invalid("colonnes CSV") }
            return Dictionary(uniqueKeysWithValues: zip(header, row))
        }
    }
}

struct GTFSSchedule: Sendable {
    typealias Row = [String: String]
    let start: String
    let end: String
    let agencies: [String: Row]
    let routes: [String: Row]
    let trips: [String: Row]
    let stations: [String: Row]
    let calendars: [String: Row]
    let exceptions: [String: String]
    let times: [String: [Row]]
    let codeCounts: [String: Int]

    init(zip data: Data) throws {
        guard data.count <= 5_000_000 else { throw ViaDataError.tooLarge }
        let archive = try Archive(data: data, accessMode: .read)
        var tables: [String: [Row]] = [:]
        var total: UInt64 = 0
        for entry in archive {
            total += entry.uncompressedSize
            guard total <= 50_000_000 else { throw ViaDataError.tooLarge }
        }
        for name in ["feed_info", "agency", "routes", "trips", "stops", "stop_times",
                     "calendar", "calendar_dates"] {
            guard let entry = archive[name + ".txt"] else { continue }
            guard entry.type == .file else { throw ViaDataError.invalid("table GTFS") }
            var contents = Data()
            let checksum = try archive.extract(entry) { chunk in
                guard contents.count + chunk.count <= 50_000_000 else { throw ViaDataError.tooLarge }
                contents.append(chunk)
            }
            guard checksum == entry.checksum else { throw ViaDataError.invalid("CRC GTFS") }
            tables[name] = try CSV.rows(contents)
        }
        try self.init(tables: tables)
    }

    init(tables: [String: [Row]]) throws {
        func table(_ name: String) throws -> [Row] {
            guard let rows = tables[name], !rows.isEmpty else {
                throw ViaDataError.invalid("table \(name) absente")
            }
            return rows
        }
        func unique(_ rows: [Row], _ key: String) throws -> [String: Row] {
            var result: [String: Row] = [:]
            for row in rows {
                let id = try row.required(key)
                guard result[id] == nil else { throw ViaDataError.invalid("identifiant GTFS dupliqué") }
                result[id] = row
            }
            return result
        }
        let info = try table("feed_info")
        guard info.count == 1 else { throw ViaDataError.invalid("horizon GTFS ambigu") }
        start = try info[0].required("feed_start_date")
        end = try info[0].required("feed_end_date")
        agencies = try unique(table("agency"), "agency_id")
        routes = try unique(table("routes"), "route_id")
        trips = try unique(table("trips"), "trip_id")
        stations = try unique(table("stops"), "stop_id")
        calendars = try unique(tables["calendar"] ?? [], "service_id")
        var changes: [String: String] = [:]
        for row in tables["calendar_dates"] ?? [] {
            let key = try row.required("service_id") + ":" + row.required("date")
            let type = try row.required("exception_type")
            guard changes[key] == nil, ["1", "2"].contains(type) else {
                throw ViaDataError.invalid("exception de calendrier")
            }
            changes[key] = type
        }
        exceptions = changes
        var groups: [String: [Row]] = [:]
        for row in try table("stop_times") {
            let trip = try row.required("trip_id"), station = try row.required("stop_id")
            guard trips[trip] != nil, stations[station] != nil,
                  let sequence = Int(try row.required("stop_sequence")), sequence >= 0 else {
                throw ViaDataError.invalid("référence d’arrêt GTFS")
            }
            groups[trip, default: []].append(row)
        }
        for (id, rows) in groups {
            _ = try unique(rows, "stop_sequence")
            groups[id] = rows.sorted { Int($0["stop_sequence"]!)! < Int($1["stop_sequence"]!)! }
        }
        times = groups
        codeCounts = Dictionary(grouping: stations.values, by: { $0["stop_code"] ?? "" }).mapValues(\.count)
    }

    func active(_ service: String, day: String) throws -> Bool {
        let instant = try ViaTime.day(day)
        let compact = day.replacingOccurrences(of: "-", with: "")
        if let exception = exceptions[service + ":" + compact] { return exception == "1" }
        guard let row = calendars[service] else { return false }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .gmt
        let weekday = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"][calendar.component(.weekday, from: instant) - 1]
        return try row.required("start_date") <= compact && compact <= row.required("end_date") && row[weekday] == "1"
    }
}

extension Dictionary where Key == String, Value == String {
    func required(_ name: String) throws -> String {
        guard let value = self[name], !value.isEmpty else { throw ViaDataError.invalid("champ \(name)") }
        return value
    }
}
