import ActivityKit
import SwiftUI
import WidgetKit

@main struct ReveilVIALiveActivity: Widget {
    private let gold = Color(red: 1, green: 0.8, blue: 0)

    private func localTime(_ date: Date, state: TripActivityAttributes.ContentState,
                           format: String = "HH:mm") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_CA")
        formatter.timeZone = TimeZone(identifier: state.timeZone ?? "America/Toronto") ?? .gmt
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    @ViewBuilder private func progress(_ state: TripActivityAttributes.ContentState) -> some View {
        if let departure = state.departure, departure < state.alarm {
            ProgressView(timerInterval: departure...state.alarm, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(gold)
            .accessibilityLabel("Temps écoulé du départ jusqu’au réveil")
        }
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Train \(context.attributes.train)", systemImage: "tram.fill")
                    Spacer()
                    Label("Réveil VIA", systemImage: "alarm.fill")
                }
                .font(.caption.weight(.semibold)).foregroundStyle(gold)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Réveil").font(.caption).foregroundStyle(.secondary)
                        Text(localTime(context.state.alarm, state: context.state))
                            .font(.system(size: 32, weight: .semibold)).monospacedDigit()
                        Text(localTime(context.state.alarm, state: context.state, format: "d MMM · z"))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Votre gare").font(.caption).foregroundStyle(.secondary)
                        Text(context.state.station).font(.title3.weight(.semibold))
                            .lineLimit(2).multilineTextAlignment(.trailing)
                    }
                }
                progress(context.state)
                HStack {
                    if context.isStale || context.state.warning {
                        Label("Suivi à actualiser · alarme conservée", systemImage: "clock")
                    } else {
                        Text("Arrivée \(context.state.estimated ? "estimée" : "prévue") : \(localTime(context.state.arrival, state: context.state))")
                        Spacer(minLength: 8)
                        Text(timerInterval: Date.distantPast...context.state.alarm, countsDown: true)
                            .monospacedDigit().multilineTextAlignment(.trailing)
                            .accessibilityLabel("Temps restant avant le réveil")
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(12)
            .activityBackgroundTint(Color(red: 0.09, green: 0.09, blue: 0.08))
            .activitySystemActionForegroundColor(.white).foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.train, systemImage: "tram.fill").foregroundStyle(gold)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label(localTime(context.state.alarm, state: context.state), systemImage: "alarm.fill")
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(context.state.station).font(.headline).lineLimit(2)
                            Spacer(minLength: 8)
                            Text(localTime(context.state.alarm, state: context.state, format: "d MMM · z"))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        progress(context.state)
                        Text(context.isStale || context.state.warning ? "Suivi à actualiser · alarme conservée" : "Temps écoulé jusqu’au réveil")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "tram.fill").foregroundStyle(gold)
            } compactTrailing: {
                Text(localTime(context.state.alarm, state: context.state)).font(.caption2).monospacedDigit()
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(gold)
            }.keylineTint(gold)
        }
    }
}
