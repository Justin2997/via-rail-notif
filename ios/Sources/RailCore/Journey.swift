import Foundation

public struct Feed: Codable, Sendable {
    public var journeys: [Journey]
    public var receivedAt: Date?
    public var generatedAt: Date
    public var error: String?
    public var notice: String
    public var attribution: String
}

public struct Journey: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var number: String
    public var serviceDate: String
    public var origin: String
    public var destination: String
    public var departure: Date
    public var stops: [StationStop]
    public var position: Position?
    public var positionObservedAt: Date?
    public var observedAt: Date?
    public var receivedAt: Date?
    public var issues: [String]
    public var liveAvailable: Bool

    public static func demo(now: Date = .now) -> Journey {
        Journey(id: "synthetic-demo", number: "DÉMO", serviceDate: "Simulation",
                origin: "Montréal", destination: "Québec", departure: now,
                stops: [StationStop(id: "2", code: "QBEC", name: "Québec",
                                    timeZone: "America/Toronto",
                                    plannedArrival: now.addingTimeInterval(1200),
                                    estimatedArrival: now.addingTimeInterval(1200),
                                    arrival: now.addingTimeInterval(1200), source: "estimated",
                                    canArm: true, issues: [])],
                position: nil, observedAt: now, receivedAt: now, issues: [], liveAvailable: true)
    }
}

public struct Position: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
}

public struct StationStop: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var code: String
    public var name: String
    public var timeZone: String
    public var plannedArrival: Date
    public var estimatedArrival: Date?
    public var arrival: Date
    public var source: String
    public var canArm: Bool
    public var issues: [String]
}

public enum WakePolicy {
    public static func hasRecentObservation(_ journey: Journey, now: Date) -> Bool {
        guard let observation = journey.observedAt, let receipt = journey.receivedAt else { return false }
        return (-30...300).contains(now.timeIntervalSince(observation)) &&
            (-30...120).contains(now.timeIntervalSince(receipt))
    }

    public static func desiredDate(arrival: Date, leadMinutes: Int) throws -> Date {
        guard (1...1440).contains(leadMinutes) else { throw WakeError.invalidLead }
        return arrival.addingTimeInterval(-Double(leadMinutes) * 60)
    }

    public static func acceptUpdate(previous: Journey, incoming: Journey,
                                    stopID: String, now: Date) -> Bool {
        guard previous.id == incoming.id, incoming.issues.isEmpty,
              let observation = incoming.observedAt,
              observation > (previous.observedAt ?? .distantPast),
              hasRecentObservation(incoming, now: now),
              let oldStop = previous.stops.first(where: { $0.id == stopID }),
              let stop = incoming.stops.first(where: { $0.id == stopID }),
              stop.code == oldStop.code, stop.plannedArrival == oldStop.plannedArrival,
              stop.canArm, stop.source == "estimated", stop.issues.isEmpty else { return false }
        return true
    }
}

public enum WakeError: LocalizedError {
    case invalidLead, blocked, immediateConfirmation, denied, unverified, inactive, stale

    public var errorDescription: String? {
        switch self {
        case .invalidLead: "Choisissez une avance de 1 à 1 440 minutes."
        case .blocked: "Cette desserte ne peut pas être utilisée pour le réveil."
        case .immediateConfirmation: "L’avance est déjà impossible. Confirmez une sonnerie immédiate."
        case .denied: "Autorisez les alarmes dans les réglages de l’iPhone."
        case .unverified: "La programmation n’a pas pu être vérifiée. Consultez l’état des alarmes."
        case .inactive: "Le réveil n’est plus actif. Une nouvelle activation est nécessaire."
        case .stale: "Actualisez les données avant d’activer ce réveil."
        }
    }
}

public enum FeedCoding {
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: raw) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: raw) else {
                throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(),
                                                       debugDescription: "Invalid absolute date")
            }
            return date
        }
        return decoder
    }
}
