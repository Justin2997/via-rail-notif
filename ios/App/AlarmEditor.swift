import RailCore
import SwiftUI

struct AlarmEditor: View {
    @Bindable var model: JourneyModel
    @State private var showInformation = false
    @State private var choosing = false
    @State private var confirmImmediate = false
    @FocusState private var editingLead: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Votre trajet") {
                    if let journey = model.selected {
                        Button { choosing = true } label: {
                            LabeledContent("Train \(journey.number)", value: "Changer")
                        }
                        Text("\(journey.origin) → \(journey.destination)")
                            .font(.subheadline).foregroundStyle(Color("SecondaryText"))
                        Text(railServiceDate(journey.serviceDate)).font(.caption).foregroundStyle(Color("SecondaryText"))
                        if let untimed = journey.untimedStops, !untimed.isEmpty {
                            Text("Certaines gares n’ont pas d’heure publiée et ne permettent pas de programmer un réveil.")
                                .font(.caption).foregroundStyle(Color("SecondaryText"))
                        }
                        Picker("Me réveiller avant", selection: $model.stopID) {
                            ForEach(journey.stops.filter { $0.id != journey.stops.first?.id }) {
                                Text($0.name).tag($0.id)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ne manquez pas votre gare.").font(.title2.bold())
                            Text("Choisissez votre train, votre gare et combien de minutes avant l’arrivée vous souhaitez être réveillé.")
                                .font(.subheadline).foregroundStyle(Color("SecondaryText"))
                        }.padding(.vertical, 12)
                        Button { choosing = true } label: {
                            Label("Choisir un train VIA", systemImage: "tram.fill")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(WakePrimaryButtonStyle())
                    }
                }.listRowBackground(Color("WakeSurface"))
                if let journey = model.selected {
                    Section {
                        AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout(spacing: 8))) {
                            ForEach([10, 15, 30], id: \.self) { minutes in
                                Button {
                                    model.leadMinutes = minutes
                                    editingLead = false
                                } label: {
                                    Text("\(minutes) min")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, minHeight: 52)
                                        .foregroundStyle(model.leadMinutes == minutes ? Color(red: 0.04, green: 0.07, blue: 0.1) : Color("WakeInk"))
                                        .background(model.leadMinutes == minutes ? Color("WakeGold") : Color("WakeBackground"),
                                                    in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(model.leadMinutes == minutes ? .isSelected : [])
                            }
                        }.listRowSeparator(.hidden)
                        HStack {
                            Text("Autre avance")
                            Spacer()
                            TextField("Minutes", value: $model.leadMinutes, format: .number)
                                .keyboardType(.numberPad).focused($editingLead)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 60)
                                .accessibilityLabel("Avance en minutes")
                            Text("min").foregroundStyle(Color("SecondaryText"))
                        }
                        if let stop = model.stop {
                            LabeledContent(stop.source == "estimated" ? "Arrivée estimée" : "Arrivée prévue") {
                                Text(railTime(stop.arrival, zone: stop.timeZone, includeDate: true)).foregroundStyle(.primary)
                            }
                        }
                        if let desired = model.desired {
                            LabeledContent("Réveil souhaité") {
                                Text(railTime(desired, zone: model.stop?.timeZone ?? "America/Toronto", includeDate: true)).foregroundStyle(.primary)
                            }.fontWeight(.semibold)
                        }
                        Button {
                            editingLead = false
                            if let desired = model.desired, desired <= .now { confirmImmediate = true }
                            else { Task { await activate() } }
                        } label: {
                            Label(model.alarm.session?.active == true ? "Modifier le réveil" : "Activer le réveil", systemImage: "alarm")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(WakePrimaryButtonStyle())
                            .disabled(model.alarm.isBusy || model.stop?.canArm != true || model.desired == nil)
                            .accessibilityIdentifier("activate-alarm")
                        if !journey.issues.isEmpty {
                            Label("Desserte à vérifier : réveil indisponible.", systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(Color("StatusWarning"))
                        }
                    } header: {
                        Text("Avance du réveil")
                    } footer: {
                        Text("L’alarme est enregistrée après activation. Un réveil existant reste actif jusque-là.")
                    }.listRowBackground(Color("WakeSurface"))
                }
                if let error = model.alarm.error {
                    Section { Text(error).font(.footnote).foregroundStyle(.red) }
                }
                Section {
                    Button("Confidentialité et sources") { showInformation = true }
                        .font(.footnote)
                }.listRowBackground(Color("WakeSurface"))
            }
            .scrollContentBackground(.hidden)
            .background { CanadianNatureBackground() }
            .navigationTitle("Votre réveil")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $choosing) { AlarmTrainPicker(model: model) }
            .sheet(isPresented: $showInformation) { AppInformationView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .disabled(model.alarm.isBusy)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Terminé") { editingLead = false }
                }
            }
            .confirmationDialog("L’avance est déjà impossible", isPresented: $confirmImmediate, titleVisibility: .visible) {
                Button("La gare est à venir : sonner maintenant") { Task { await activate(immediate: true) } }
            } message: {
                Text("Une alarme sera demandée dans cinq secondes. Confirmez que la gare est encore à venir, ou modifiez l’avance.")
            }
        }
    }

    private func activate(immediate: Bool = false) async {
        await model.activate(immediate: immediate)
        if model.alarm.error == nil, model.alarm.session?.active == true,
           !model.alarm.observed.isEmpty {
            dismiss()
        }
    }

}

private struct AlarmTrainPicker: View {
    @Bindable var model: JourneyModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Date du voyage", selection: $model.date, displayedComponents: .date)
                        .environment(\.timeZone, TimeZone(identifier: "America/Toronto")!)
                        .disabled(model.isLoading)
                    if model.isLoading { ProgressView("Chargement VIA…") }
                    if let error = model.error { Text(error).font(.footnote).foregroundStyle(Color("SecondaryText")) }
                }
                ForEach(model.filtered) { journey in
                    Button { model.select(journey); dismiss() } label: { TrainRow(journey: journey) }
                        .foregroundStyle(.primary)
                }
                if model.filtered.isEmpty && !model.isLoading {
                    Text("Aucun train pour cette recherche.").foregroundStyle(Color("SecondaryText"))
                    Button("Actualiser") { Task { await model.load() } }
                }
            }
            .scrollContentBackground(.hidden)
            .background { CanadianNatureBackground() }
            .navigationTitle("Choisir un train")
            .searchable(text: $model.number, prompt: "Train ou gare")
            .toolbar { Button("Fermer") { dismiss() } }
            .onChange(of: model.serviceDate) { _, _ in Task { await model.load() } }
            .task { if model.feedDate != model.serviceDate { await model.load() } }
        }
    }
}
