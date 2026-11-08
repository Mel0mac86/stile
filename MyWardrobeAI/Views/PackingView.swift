import SwiftUI
import SwiftData

/// Valigia automatica: quanti capi servono per la durata del viaggio, con il meteo della destinazione.
struct PackingView: View {
    @Query(sort: \Garment.dateAdded) private var garments: [Garment]

    @State private var destination = ""
    @State private var days = 5
    @State private var startDate = Date()
    @State private var plan: PackingPlanner.Plan?
    @State private var packed: Set<UUID> = []
    @State private var status: String?
    @State private var working = false
    @State private var weatherService = WeatherService()

    var body: some View {
        Form {
            Section {
                TextField("Destinazione (es. Lisbona)", text: $destination)
                Stepper("Durata: \(days) giorni", value: $days, in: 1...30)
                DatePicker("Partenza", selection: $startDate, displayedComponents: .date)
                Button {
                    Task { await buildPlan() }
                } label: {
                    if working {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Crea valigia", systemImage: "suitcase").frame(maxWidth: .infinity)
                    }
                }
                .disabled(working || garments.isEmpty)
            } header: {
                Text("Viaggio")
            } footer: {
                Text("Con una destinazione l'app legge le previsioni per il periodo (fino a 16 giorni) e sceglie capi adatti al clima. Senza, usa la stagione.")
            }

            if let status {
                Section {
                    Text(status).foregroundStyle(.orange)
                }
            }

            if let plan {
                if !plan.warnings.isEmpty {
                    Section("Da acquistare o da aggiungere") {
                        ForEach(plan.warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Section("Checklist (\(packed.count)/\(plan.items.count))") {
                    ForEach(plan.items) { item in
                        Button {
                            if packed.contains(item.id) { packed.remove(item.id) } else { packed.insert(item.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: packed.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(packed.contains(item.id) ? .green : .secondary)
                                GarmentImage(cutout: item.cutoutFileName, photo: item.photoFileName)
                                    .frame(width: 44, height: 52)
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .strikethrough(packed.contains(item.id))
                                    Text(item.category.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Valigia")
    }

    /// Legge il meteo della destinazione (se indicata), poi sceglie i capi.
    private func buildPlan() async {
        working = true
        status = nil
        defer { working = false }

        var temperature: Double?
        var rainy = false
        let place = destination.trimmingCharacters(in: .whitespaces)
        if !place.isEmpty {
            do {
                if let found = try await weatherService.geocode(place) {
                    let forecast = try await weatherService.forecast(latitude: found.latitude, longitude: found.longitude, days: 16)
                    let calendar = Calendar.current
                    let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now),
                                                         to: calendar.startOfDay(for: startDate)).day ?? 0
                    let slice = Array(forecast.daily.dropFirst(max(0, offset)).prefix(days))
                    if slice.isEmpty {
                        status = "Le previsioni arrivano solo per i prossimi 16 giorni: uso la stagione."
                    } else {
                        temperature = slice.map { ($0.maxTemp + $0.minTemp) / 2 }.reduce(0, +) / Double(slice.count)
                        rainy = slice.contains { $0.rainChance >= 50 }
                    }
                } else {
                    status = "Località non trovata: uso la stagione."
                }
            } catch {
                status = "Meteo non disponibile: uso la stagione."
            }
        }

        let ctx = OutfitEngine.context(
            occasion: .trip, season: Season.of(startDate), temperature: temperature,
            isRaining: rainy, rated: [], preferredStyle: ""
        )
        plan = PackingPlanner.plan(garments: garments.map(GarmentSnapshot.init), days: days, context: ctx)
        packed = []
    }
}
