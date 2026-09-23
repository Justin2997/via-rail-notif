import ActivityKit
import SwiftUI
import WidgetKit

@main struct ReveilVIALiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Réveil VIA · \(context.attributes.train)", systemImage: "tram.fill")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "alarm.fill").foregroundStyle(.yellow)
                }
                Text(context.state.station).font(.title2.bold()).lineLimit(1)
                HStack {
                    VStack(alignment: .leading) {
                        Text("Réveil enregistré").font(.caption)
                        Text(context.state.alarm, style: .time).font(.title2.monospacedDigit())
                    }
                    Spacer()
                    Text(timerInterval: Date.distantPast...context.state.alarm, countsDown: true)
                        .font(.title2.monospacedDigit()).multilineTextAlignment(.trailing)
                }
                Text(context.isStale || context.state.warning ?
                     "Suivi à actualiser · alarme conservée" :
                     "\(context.state.estimated ? "Arrivée estimée" : "Horaire prévu") : \(context.state.arrival.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding().activityBackgroundTint(Color(red: 0.03, green: 0.1, blue: 0.23))
                .activitySystemActionForegroundColor(.white).foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.train, systemImage: "tram.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.alarm, style: .time).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        Text(context.state.station).font(.headline)
                        Text(context.isStale || context.state.warning ? "Suivi à actualiser" : "Réveil enregistré")
                            .font(.caption)
                    }
                }
            } compactLeading: {
                Image(systemName: "tram.fill").foregroundStyle(.yellow)
            } compactTrailing: {
                Text(context.state.alarm, style: .time).font(.caption2).monospacedDigit()
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(.yellow)
            }.keylineTint(.yellow)
        }
    }
}
