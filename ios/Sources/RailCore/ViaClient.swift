import Foundation

public enum ViaSource: String, Sendable {
    case schedule = "https://www.viarail.ca/sites/all/files/gtfs/viarail.zip"
    case live = "https://tsimobile.viarail.ca/data/allData.json"
    var limit: Int { self == .schedule ? 5_000_000 : 2_000_000 }
}

public protocol ViaTransport: Sendable {
    func download(_ source: ViaSource) async throws -> Data
}

public struct ViaHTTPS: ViaTransport {
    public init() {}
    public func download(_ source: ViaSource) async throws -> Data {
        var request = URLRequest(url: URL(string: source.rawValue)!, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 30
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard response.statusCode == 200 else { throw ViaDataError.http(response.statusCode) }
        guard response.expectedContentLength <= source.limit else { throw ViaDataError.tooLarge }
        var data = Data()
        data.reserveCapacity(min(source.limit, max(0, Int(response.expectedContentLength))))
        for try await byte in bytes {
            guard data.count < source.limit else { throw ViaDataError.tooLarge }
            data.append(byte)
        }
        return data
    }
}

private struct CachedSources: Codable, Sendable {
    var schedule: Data?
    var scheduleReceivedAt: Date?
    var live: Data?
    var liveReceivedAt: Date?
    var ordering = LiveOrdering()
}

public actor ViaClient {
    private let transport: any ViaTransport
    private let cacheURL: URL?
    private let clock: @Sendable () -> Date
    private var cache: CachedSources
    private var inFlight: Task<Feed, Error>?
    private var lastAttempt: Date?
    private var parsedSchedule: GTFSSchedule?
    private var warnings: [String] = []

    public init(transport: any ViaTransport = ViaHTTPS(), cacheURL: URL? = nil,
                clock: @escaping @Sendable () -> Date = { .now }) {
        self.transport = transport
        self.cacheURL = cacheURL
        self.clock = clock
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let saved = try? JSONDecoder().decode(CachedSources.self, from: data) {
            cache = saved
        } else { cache = CachedSources() }
    }

    public func load(serviceDate: String) async throws -> Feed {
        _ = try ViaTime.day(serviceDate)
        if let inFlight {
            _ = try await inFlight.value
            return try normalized(day: serviceDate, now: clock())
        }
        // Concurrent screens share one transfer; parsing and ZIP work remain off the main actor.
        let task = Task { try await self.refresh(day: serviceDate, now: self.clock()) }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    private func refresh(day: String, now: Date) async throws -> Feed {
        if parsedSchedule == nil, let data = cache.schedule { parsedSchedule = try? GTFSSchedule(zip: data) }
        let compact = day.replacingOccurrences(of: "-", with: "")
        let inHorizon = parsedSchedule.map { $0.start <= compact && compact <= $0.end } == true
        let scheduleAge = now.timeIntervalSince(cache.scheduleReceivedAt ?? .distantPast)
        if let lastAttempt, now.timeIntervalSince(lastAttempt) >= 0 && now.timeIntervalSince(lastAttempt) < 60,
           parsedSchedule != nil, inHorizon {
            return try normalized(day: day, now: now)
        }
        lastAttempt = now
        warnings = []
        if parsedSchedule == nil || !inHorizon || scheduleAge > 21600 || scheduleAge < -30 {
            do {
                let data = try await transport.download(.schedule)
                let schedule = try GTFSSchedule(zip: data)
                parsedSchedule = schedule
                cache.schedule = data
                cache.scheduleReceivedAt = clock()
            } catch {
                guard parsedSchedule != nil, inHorizon else { throw error }
                warnings.append("Horaires sauvegardés sur l’iPhone : actualisation indisponible.")
            }
        }
        do {
            let data = try await transport.download(.live)
            _ = try JSONDecoder().decode([String: LiveTrain].self, from: data)
            cache.live = data
            cache.liveReceivedAt = clock()
        } catch {
            warnings.append("Suivi VIA indisponible. Dernier relevé conservé avec sa date d’origine.")
        }
        let feed = try normalized(day: day, now: clock())
        if let cacheURL {
            do {
                try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(cache).write(to: cacheURL, options: .atomic)
            } catch {
                warnings.append("Le cache n’a pas pu être sauvegardé sur l’iPhone.")
                return try normalized(day: day, now: clock())
            }
        }
        return feed
    }

    private func normalized(day: String, now: Date) throws -> Feed {
        guard let schedule = parsedSchedule else { throw ViaDataError.invalid("horaires absents") }
        let live = try cache.live.map { try JSONDecoder().decode([String: LiveTrain].self, from: $0) } ?? [:]
        let ordered = cache.ordering.validate(live)
        return Feed(journeys: try schedule.journeys(day: day, live: ordered, receivedAt: cache.liveReceivedAt, now: now),
                    receivedAt: cache.liveReceivedAt, generatedAt: now,
                    error: warnings.isEmpty ? nil : warnings.joined(separator: " "),
                    notice: "Connexion directe à VIA Rail. Âge des prévisions inconnu.",
                    attribution: "Source : VIA Rail Canada inc. Horaires GTFS sous Licence du gouvernement ouvert – Canada.")
    }
}
