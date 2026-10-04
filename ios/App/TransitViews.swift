import RailCore
import SwiftUI

func railTime(_ date: Date, zone: String = "America/Toronto", includeDate: Bool = false) -> String {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.timeZone = TimeZone(identifier: zone)
    formatter.setLocalizedDateFormatFromTemplate(includeDate ? "dMMMjmz" : "jm")
    return formatter.string(from: date)
}

func railServiceDate(_ value: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = TimeZone(identifier: "America/Toronto")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: value) else { return value }
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.timeZone = parser.timeZone
    formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy")
    return formatter.string(from: date)
}

struct TrainStatus: View {
    let journey: Journey
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Label(JourneyDisplay.status(journey, now: context.date),
                  systemImage: !journey.issues.isEmpty ? "exclamationmark.triangle" :
                    JourneyDisplay.hasLiveEstimate(journey, now: context.date) ? "dot.radiowaves.left.and.right" : "clock")
                .font(.caption.weight(.medium))
                .foregroundStyle(!journey.issues.isEmpty ? Color("StatusWarning") :
                    JourneyDisplay.hasLiveEstimate(journey, now: context.date) ? Color("StatusPositive") : Color("SecondaryText"))
        }
    }
}

struct TrainRow: View {
    let journey: Journey
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                Text(String(localized: "Train \(String(journey.number))")).font(.headline)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                TrainStatus(journey: journey)
            }
            Text("\(journey.origin) → \(journey.destination)")
                .font(.subheadline).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let last = journey.stops.last {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Départ \(String(railTime(journey.departure, zone: journey.stops.first?.timeZone ?? "America/Toronto", includeDate: true)))"))
                        Text("\(JourneyDisplay.isEstimated(last, in: journey, now: context.date) ? String(localized: "Estimée") : String(localized: "Prévue")) \(railTime(JourneyDisplay.arrival(last, in: journey, now: context.date), zone: last.timeZone, includeDate: true))")
                    }.font(.caption).monospacedDigit().foregroundStyle(Color("SecondaryText"))
                }
            }
        }.padding(.vertical, 8)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .accessibilityElement(children: .combine)
    }
}

struct DataReceipt: View {
    let feed: Feed?
    let loading: Bool
    var receivedAt: Date? = nil
    var body: some View {
        if let receipt = receivedAt ?? feed?.receivedAt {
            Text(loading ? String(localized: "Actualisation… · données du \(String(railTime(receipt, includeDate: true)))") :
                 String(localized: "Mis à jour à \(String(railTime(receipt, includeDate: true)))"))
                .font(.caption).foregroundStyle(Color("SecondaryText"))
        } else if loading {
            Text(String(localized: "Actualisation…"))
                .font(.caption).foregroundStyle(Color("SecondaryText"))
        }
    }
}
