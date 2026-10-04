import RailCore
import SwiftUI

struct DashboardView: View {
    @Bindable var model: JourneyModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: model.trackedJourney == nil ? 24 : 10) {
                    if let journey = model.trackedJourney {
                        activeJourney(journey)
                    } else {
                        ViaCompanionBanner()
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background { CanadianNatureBackground() }
            .navigationTitle(String(localized: "Réveil VIA"))
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await model.load() }
        }
    }

    @ViewBuilder private func activeJourney(_ journey: Journey) -> some View {
        if let session = model.alarm.session {
            AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                Text(String(localized: "Train \(String(journey.number))")).font(.headline)
                if !typeSize.isAccessibilitySize { Spacer() }
                Text(railServiceDate(journey.serviceDate))
                    .font(.caption).foregroundStyle(Color("SecondaryText"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WakeClock(alarms: model.alarm.observed, station: session.stop?.name ?? String(localized: "Votre gare"),
                      zone: session.stop?.timeZone ?? "America/Toronto", leadMinutes: session.leadMinutes)

            VStack(spacing: 6) {
                Label(model.alarm.observed.contains(where: { $0.ringing }) ? String(localized: "Sonnerie en cours") : model.alarm.status,
                      systemImage: model.alarm.observed.contains(where: { $0.ringing }) ? "alarm.waves.left.and.right" : "alarm")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color("WakeInk"))
                    .multilineTextAlignment(.center)
                if model.alarm.observed.contains(where: { $0.ringing }) {
                    Button { Task { await model.stopAlarm() } } label: {
                        Label(String(localized: "Je suis réveillé · arrêter"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WakePrimaryButtonStyle(gold: true, compact: true))
                    .disabled(model.alarm.isBusy)
                    .accessibilityIdentifier("stop-alarm")
                }
                Button { model.configure(journey, stopID: session.stopID) } label: {
                    HStack {
                        Label(String(localized: "Modifier le réveil"), systemImage: "slider.horizontal.3")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(WakePrimaryButtonStyle(compact: true))
                .accessibilityIdentifier("manage-alarm")
                if !model.alarm.observed.contains(where: { $0.ringing }),
                   session.active || !model.alarm.observed.isEmpty {
                    Button(String(localized: "Désactiver le réveil"), role: .destructive) {
                        Task { await model.stopAlarm() }
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
                    .disabled(model.alarm.isBusy)
                    .accessibilityIdentifier("stop-alarm")
                }
            }

            WakeArrivalSummary(journey: journey, stopID: session.stopID,
                               registeredAlarm: model.alarm.observed.count == 1 ? model.alarm.observed.first : nil)

            NavigationLink {
                JourneyDashboard(model: model, fallback: journey)
            } label: {
                HStack {
                    Label(String(localized: "Gares et position publiée"), systemImage: "tram")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }.font(.subheadline)
                    .frame(minHeight: 44)
            }
            .foregroundStyle(Color("WakeInk"))
            .accessibilityIdentifier("tracked-train-\(journey.number)")

            VStack(spacing: 8) {
                DataReceipt(feed: nil, loading: model.isLoading, receivedAt: journey.receivedAt)
                if let message = model.activityMessage {
                    Label(message, systemImage: "lock.rectangle")
                        .font(.footnote).foregroundStyle(Color("StatusWarning"))
                }
                if let error = model.alarm.error ?? model.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Color("StatusWarning"))
                }
            }.multilineTextAlignment(.center)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            VStack(spacing: 20) {
                Text(String(localized: "Reposez-vous.\nGardez votre gare en vue."))
                    .font(.largeTitle.weight(.semibold)).tracking(-0.8)
                    .foregroundStyle(Color("WakeInk"))
                Text(String(localized: "Choisissez votre train et votre gare.\nProgrammez un réveil avant l’arrivée."))
                    .font(.body).foregroundStyle(Color("SecondaryText"))
            }.multilineTextAlignment(.center).padding(.top, 4)
            Button { model.showAlarmEditor = true } label: {
                Label(String(localized: "Configurer un réveil"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(WakePrimaryButtonStyle())
            Text(String(localized: "Votre train apparaîtra ici une fois le réveil activé."))
                .font(.footnote).foregroundStyle(Color("SecondaryText"))
                .multilineTextAlignment(.center)
        }
    }
}

/// The landscape is bundled, so the background needs no network access.
struct CanadianNatureBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("CanadianNature")
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                LinearGradient(
                    stops: [
                        .init(color: Color("WakeBackground").opacity(colorScheme == .dark ? 0.45 : 0.55), location: 0),
                        .init(color: Color("WakeBackground").opacity(colorScheme == .dark ? 0.65 : 0.75), location: 0.42),
                        .init(color: Color("WakeBackground").opacity(colorScheme == .dark ? 0.32 : 0.45), location: 1)
                    ], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Bundled VIA photography remains available while the passenger is offline.
struct ViaCompanionBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("ViaTrain")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .accessibilityLabel(String(localized: "Train de la nouvelle flotte VIA Rail Canada"))
            VStack(alignment: .leading, spacing: 4) {
                Text("VIA Rail Canada")
                    .font(.title3.weight(.bold))
                Text(String(localized: "Votre compagnon de voyage"))
                    .font(.subheadline)
            }
            .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.12))
            .padding(.horizontal, 20).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("WakeGold"))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct WakePrimaryButtonStyle: ButtonStyle {
    var gold = true
    var compact = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20).padding(.vertical, compact ? 13 : 18)
            .foregroundStyle(gold ? Color(red: 0.04, green: 0.07, blue: 0.1) : Color("WakeOnButton"))
            .background(Color(gold ? "WakeGold" : "WakeButton"), in: RoundedRectangle(cornerRadius: 16))
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.8 : 1)
    }
}

private struct WakeClock: View {
    let alarms: [DeviceAlarm]
    let station: String
    let zone: String
    let leadMinutes: Int
    @ScaledMetric(relativeTo: .largeTitle) private var clockSize = 64

    var body: some View {
        VStack(spacing: 6) {
            Text(alarms.contains(where: { $0.ringing }) ? String(localized: "C’est l’heure de vous réveiller") : alarms.count == 1 ? String(localized: "Réveil programmé") : String(localized: "État du réveil"))
                .font(.subheadline.weight(.medium)).foregroundStyle(Color("SecondaryText"))
            if alarms.count == 1, let alarm = alarms.first {
                Text(railTime(alarm.date, zone: zone))
                    .font(.system(size: clockSize, weight: .semibold, design: .rounded))
                    .monospacedDigit().tracking(-3)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .accessibilityLabel(String(localized: "Réveil à \(String(railTime(alarm.date, zone: zone, includeDate: true)))"))
                Text(railTime(alarm.date, zone: zone, includeDate: true))
                    .font(.subheadline).foregroundStyle(Color("SecondaryText"))
            } else {
                Text(alarms.isEmpty ? String(localized: "Heure à vérifier") : String(localized: "Plusieurs alarmes"))
                    .font(.title.weight(.semibold))
                ForEach(alarms, id: \.id) { alarm in
                    Text(railTime(alarm.date, zone: zone, includeDate: true)).font(.headline)
                }
            }
            Text(station).font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "Avance choisie : \(String(leadMinutes)) min"))
                .font(.subheadline).foregroundStyle(Color("SecondaryText"))
        }
        .foregroundStyle(Color("WakeInk"))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity).padding(.vertical, 4)
    }
}

private struct WakeArrivalSummary: View {
    let journey: Journey
    let stopID: String
    var registeredAlarm: DeviceAlarm? = nil
    @Environment(\.dynamicTypeSize) private var typeSize

    private func arrivalTime(_ arrival: Date, zone: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .current
        return railTime(arrival, zone: zone,
                        includeDate: !calendar.isDate(arrival, inSameDayAs: journey.departure))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 10) {
                let progress = registeredAlarm.flatMap {
                    JourneyDisplay.wakeProgress(departure: journey.departure, alarm: $0.date, now: context.date)
                }
                AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())) {
                    TrainStatus(journey: journey)
                    if !typeSize.isAccessibilitySize { Spacer() }
                    if let progress {
                        Text(String(localized: "\(String(Int(progress * 100))) % du temps écoulé"))
                            .font(.caption).monospacedDigit().foregroundStyle(Color("SecondaryText"))
                    }
                }
                if let progress {
                    ProgressView(value: progress)
                        .tint(Color("WakeGold"))
                        .accessibilityLabel(String(localized: "Temps écoulé du départ au réveil programmé"))
                        .accessibilityValue(String(localized: "\(String(Int(progress * 100))) pour cent"))
                }
                if let stop = journey.stops.first(where: { $0.id == stopID }) {
                    AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 20))) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "Départ")).font(.caption).foregroundStyle(Color("SecondaryText"))
                            Text(journey.origin).font(.headline)
                            Text(railTime(journey.departure, zone: journey.stops.first?.timeZone ?? "America/Toronto", includeDate: true)).font(.subheadline).monospacedDigit()
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(JourneyDisplay.isEstimated(stop, in: journey, now: context.date) ? String(localized: "Arrivée estimée") : String(localized: "Arrivée prévue"))
                                .font(.caption).foregroundStyle(Color("SecondaryText"))
                            Text(stop.name).font(.headline)
                            let arrival = JourneyDisplay.arrival(stop, in: journey, now: context.date)
                            Text(arrival > context.date ? arrivalTime(arrival, zone: stop.timeZone) : String(localized: "Arrivée à confirmer"))
                                .font(.subheadline).monospacedDigit()
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .foregroundStyle(Color("WakeInk"))
            .padding(16)
            .background(Color("WakeSurface").opacity(0.93), in: RoundedRectangle(cornerRadius: 18))
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
                                Text(String(localized: "\(String(JourneyDisplay.isEstimated(last, in: journey, now: context.date) ? String(localized: "Arrivée estimée") : String(localized: "Arrivée prévue"))) à \(String(last.name))"))
                                    .font(.subheadline).foregroundStyle(Color("SecondaryText"))
                                if arrival > context.date {
                                    Text(arrival, style: .timer)
                                        .font(.system(.largeTitle, design: .rounded).weight(.medium)).monospacedDigit()
                                } else {
                                    Text(String(localized: "Arrivée à confirmer")).font(.title3.weight(.medium))
                                }
                                Text(railTime(arrival, zone: last.timeZone, includeDate: true))
                                    .font(.subheadline).monospacedDigit()
                            }
                        }
                    }
                }.padding(.vertical, 10)
                NavigationLink { TrainMap(journey: journey) } label: {
                    Label(String(localized: "Position publiée"), systemImage: "map")
                }
            }
            Section(String(localized: "Gares et arrivées")) {
                ForEach(journey.stops) { stop in
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(stop.name).font(.headline)
                                Spacer()
                                Text(railTime(JourneyDisplay.arrival(stop, in: journey, now: context.date), zone: stop.timeZone, includeDate: true))
                                    .monospacedDigit()
                            }
                            Text(JourneyDisplay.isEstimated(stop, in: journey, now: context.date) ?
                                 String(localized: "Estimée · horaire prévu \(String(railTime(stop.plannedArrival, zone: stop.timeZone, includeDate: true)))") : String(localized: "Horaire prévu"))
                                .font(.caption).foregroundStyle(Color("SecondaryText"))
                        }.padding(.vertical, 4)
                    }
                }
            }
            if let untimed = journey.untimedStops, !untimed.isEmpty {
                Section(String(localized: "Gares sans horaire publié")) {
                    ForEach(untimed) { stop in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stop.name)
                            Text(String(localized: "Horaire indisponible · réveil indisponible à cette gare"))
                                .font(.caption).foregroundStyle(Color("SecondaryText"))
                        }
                    }
                }
            }
            Section {
                Button {
                    model.configure(journey, stopID: model.alarm.session?.stopID)
                } label: {
                    Label(String(localized: "Gérer le réveil"), systemImage: "alarm")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(WakePrimaryButtonStyle())
                if !journey.issues.isEmpty {
                    Text(String(localized: "Les sources ne concordent pas pour cette desserte. L’activation du réveil reste bloquée tant que le conflit persiste."))
                        .font(.footnote).foregroundStyle(Color("SecondaryText"))
                }
                DataReceipt(feed: nil, loading: model.isLoading, receivedAt: journey.receivedAt)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("WakeBackground"))
        .navigationTitle(String(localized: "Train \(String(journey.number))"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
    }
}

#Preview(String(localized: "Réveil enregistré")) {
    WakeClock(alarms: [DeviceAlarm(id: UUID(), date: Date(timeIntervalSince1970: 1791144480))],
              station: "Toronto Union", zone: "America/Toronto", leadMinutes: 20)
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("WakeBackground"))
}

#Preview(String(localized: "État à vérifier")) {
    WakeClock(alarms: [], station: "Toronto Union", zone: "America/Toronto", leadMinutes: 20)
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("WakeBackground"))
}
