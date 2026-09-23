import RailCore
import SwiftUI

func railTime(_ date: Date, zone: String = "America/Toronto", includeDate: Bool = false) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_CA")
    formatter.timeZone = TimeZone(identifier: zone)
    formatter.dateFormat = includeDate ? "d MMM, HH:mm z" : "HH:mm"
    return formatter.string(from: date)
}

func railServiceDate(_ value: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = TimeZone(identifier: "America/Toronto")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: value) else { return value }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_CA")
    formatter.timeZone = parser.timeZone
    formatter.dateFormat = "d MMM yyyy"
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
                Text("Train \(journey.number)").font(.headline)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                TrainStatus(journey: journey)
            }
            Text("\(journey.origin) → \(journey.destination)")
                .font(.subheadline).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let last = journey.stops.last {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                        Text("Départ \(railTime(journey.departure))")
                        if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                        Text("\(JourneyDisplay.isEstimated(last, in: journey, now: context.date) ? "Estimée" : "Prévue") \(railTime(JourneyDisplay.arrival(last, in: journey, now: context.date), zone: last.timeZone))")
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
            Text(loading ? "Actualisation… · données du \(railTime(receipt, includeDate: true))" :
                 "Mis à jour à \(railTime(receipt, includeDate: true))")
                .font(.caption).foregroundStyle(Color("SecondaryText"))
        } else if loading {
            Text("Actualisation…")
                .font(.caption).foregroundStyle(Color("SecondaryText"))
        }
    }
}
