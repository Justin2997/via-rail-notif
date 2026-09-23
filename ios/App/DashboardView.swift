import RailCore
import SwiftUI

struct DashboardView: View {
    @Bindable var model: JourneyModel

    var body: some View {
        NavigationStack {
            List {
                if let journey = model.trackedJourney {
                    Section("Votre train suivi") {
                        NavigationLink {
                            JourneyDashboard(model: model, fallback: journey)
                        } label: { TrainRow(journey: journey) }
                        .accessibilityIdentifier("tracked-train-\(journey.number)")
                        Text(railServiceDate(journey.serviceDate))
                            .font(.caption).foregroundStyle(Color("SecondaryText"))
                        if let stop = model.alarm.session?.stop {
                            Label("Réveil pour \(stop.name)", systemImage: "alarm")
                                .font(.subheadline)
                        }
                        Button {
                            model.configure(journey, stopID: model.alarm.session?.stopID)
                        } label: {
                            Label("Gérer le réveil", systemImage: "slider.horizontal.3")
                        }
                    }
                    Section {
                        DataReceipt(feed: nil, loading: model.isLoading, receivedAt: journey.receivedAt)
                        if let error = model.error {
                            Label(error, systemImage: "wifi.exclamationmark")
                                .font(.footnote).foregroundStyle(Color("SecondaryText"))
                        }
                    } footer: {
                        Text("Le suivi se met à jour quand l’app est ouverte. Une heure prévue n’est pas une estimation en temps réel.")
                    }
                } else {
                    Section {
                        ContentUnavailableView("Aucun train à suivre", systemImage: "alarm",
                            description: Text("Activez un réveil pour retrouver ici le suivi de votre train."))
                        Button { model.showAlarmEditor = true } label: {
                            Label("Configurer un réveil", systemImage: "plus")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).foregroundStyle(Color("OnAccentColor"))
                    }
                }
            }
            .navigationTitle("Temps réel")
            .refreshable { await model.load() }
        }
    }
}

struct JourneyDashboard: View {
    @Bindable var model: JourneyModel
    let fallback: Journey
    private var journey: Journey { model.journey(id: fallback.id) ?? fallback }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    TrainStatus(journey: journey)
                    Text("\(journey.origin) → \(journey.destination)")
                        .font(.title2.bold())
                    Text(railServiceDate(journey.serviceDate)).font(.subheadline).foregroundStyle(Color("SecondaryText"))
                    if let last = journey.stops.first(where: { $0.id == model.alarm.session?.stopID }) ?? journey.stops.last {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let arrival = JourneyDisplay.arrival(last, in: journey, now: context.date)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(JourneyDisplay.isEstimated(last, in: journey, now: context.date) ? "Arrivée estimée" : "Arrivée prévue") à \(last.name)")
                                    .font(.subheadline).foregroundStyle(Color("SecondaryText"))
                                if arrival > context.date {
                                    Text(arrival, style: .timer)
                                        .font(.system(.largeTitle, design: .rounded).weight(.medium)).monospacedDigit()
                                } else {
                                    Text("Arrivée à confirmer").font(.title3.weight(.medium))
                                }
                                Text(railTime(arrival, zone: last.timeZone, includeDate: true))
                                    .font(.subheadline).monospacedDigit()
                            }
                        }
                    }
                }.padding(.vertical, 10)
                NavigationLink { TrainMap(journey: journey) } label: {
                    Label("Position publiée", systemImage: "map")
                }
            }
            Section("Gares et arrivées") {
                ForEach(journey.stops) { stop in
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(stop.name).font(.headline)
                                Spacer()
                                Text(railTime(JourneyDisplay.arrival(stop, in: journey, now: context.date), zone: stop.timeZone))
                                    .monospacedDigit()
                            }
                            Text(JourneyDisplay.isEstimated(stop, in: journey, now: context.date) ?
                                 "Estimée · horaire prévu \(railTime(stop.plannedArrival, zone: stop.timeZone))" : "Horaire prévu")
                                .font(.caption).foregroundStyle(Color("SecondaryText"))
                        }.padding(.vertical, 4)
                    }
                }
            }
            Section {
                Button {
                    model.configure(journey, stopID: model.alarm.session?.stopID)
                } label: {
                    Label("Gérer le réveil", systemImage: "alarm")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).foregroundStyle(Color("OnAccentColor"))
                if !journey.issues.isEmpty {
                    Text("Les sources ne concordent pas pour cette desserte. L’activation du réveil reste bloquée tant que le conflit persiste.")
                        .font(.footnote).foregroundStyle(Color("SecondaryText"))
                }
                DataReceipt(feed: nil, loading: model.isLoading, receivedAt: journey.receivedAt)
            }
        }
        .navigationTitle("Train \(journey.number)")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
    }
}
