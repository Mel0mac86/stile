import SwiftUI
import SwiftData

/// Un outfit generato insieme al suo contesto, pronto per la schermata di dettaglio.
struct StylistResult: Identifiable {
    let suggestion: OutfitSuggestion
    let session: OutfitSession
    var id: UUID { suggestion.id }
}

/// Stilista AI: sceglie occasione, stagione e meteo, poi propone outfit con i capi del guardaroba.
struct StylistView: View {
    @Query(sort: \Garment.dateAdded) private var garments: [Garment]
    @Query private var savedOutfits: [SavedOutfit]
    @AppStorage(AppSettings.weatherConsentKey) private var weatherConsent = false
    @AppStorage(AppSettings.preferredStyleKey) private var preferredStyle = ""
    @AppStorage(AppSettings.manualTempEnabledKey) private var manualTempEnabled = false
    @AppStorage(AppSettings.manualTempKey) private var manualTemp = 20.0

    @State private var occasion: Occasion = .work
    @State private var freeText = ""
    @State private var season: Season = .current
    @State private var weather: WeatherService.Current?
    @State private var weatherMessage: String?
    @State private var loadingWeather = false
    @State private var weatherService = WeatherService()
    @State private var results: [StylistResult] = []
    @State private var missing: [String] = []
    @State private var searched = false

    /// Temperatura: quella letta dal meteo, altrimenti quella impostata a mano.
    private var temperature: Double? {
        if let w = weather { return w.temperature }
        return manualTempEnabled ? manualTemp : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Occasione") {
                    Picker("Occasione", selection: $occasion) {
                        ForEach(Occasion.allCases) { Label($0.rawValue, systemImage: $0.symbolName).tag($0) }
                    }
                    TextField("Oppure descrivila (es. festa in terrazza)", text: $freeText)
                }

                Section("Stagione") {
                    Picker("Stagione", selection: $season) {
                        ForEach(Season.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Usa la posizione per il meteo", isOn: $weatherConsent)
                    if weatherConsent {
                        if let w = weather {
                            LabeledContent("Temperatura", value: "\(Int(w.temperature.rounded()))°C")
                            LabeledContent("Pioggia", value: w.isRaining ? "Sì" : "No")
                            LabeledContent("Vento", value: "\(Int(w.windSpeed)) km/h")
                            LabeledContent("Umidità", value: "\(Int(w.humidity))%")
                        }
                        Button(weather == nil ? "Leggi il meteo" : "Aggiorna meteo") {
                            Task { await loadWeather() }
                        }
                        .disabled(loadingWeather)
                        if let message = weatherMessage {
                            Text(message).font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        Toggle("Imposto io la temperatura", isOn: $manualTempEnabled)
                        if manualTempEnabled {
                            Slider(value: $manualTemp, in: -5...38, step: 1)
                            Text("\(Int(manualTemp))°C").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Meteo")
                } footer: {
                    Text("La posizione serve solo a leggere il meteo: non viene salvata né condivisa. Dati Open-Meteo.")
                }

                Section {
                    Button {
                        generate(random: false)
                    } label: {
                        Label("Crea outfit", systemImage: "sparkles").frame(maxWidth: .infinity)
                    }
                    .disabled(garments.isEmpty)
                    Button {
                        generate(random: true)
                    } label: {
                        Label("Outfit casuale", systemImage: "shuffle").frame(maxWidth: .infinity)
                    }
                    .disabled(garments.isEmpty)
                } footer: {
                    if garments.isEmpty {
                        Text("Aggiungi nel guardaroba almeno una maglia, un pantalone e un paio di scarpe.")
                    }
                }

                if searched {
                    Section("Proposte") {
                        ForEach(missing, id: \.self) { item in
                            Label(item, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        if results.isEmpty && missing.isEmpty {
                            Text("Nessun abbinamento possibile con i capi attuali.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            NavigationLink(value: result.session) {
                                OutfitCard(title: "Proposta \(index + 1)", suggestion: result.suggestion)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }
                }

                Section("Viaggi") {
                    NavigationLink {
                        PackingView()
                    } label: {
                        Label("Valigia automatica", systemImage: "suitcase")
                    }
                }
            }
            .navigationTitle("Stilista AI")
            .navigationDestination(for: OutfitSession.self) { OutfitDetailView(session: $0) }
            .onChange(of: weatherConsent) { _, on in
                if !on {
                    weather = nil
                    weatherMessage = nil
                }
            }
        }
    }

    private func loadWeather() async {
        loadingWeather = true
        defer { loadingWeather = false }
        do {
            weather = try await weatherService.loadCurrentWeather()
            weatherMessage = nil
        } catch {
            weatherMessage = error.localizedDescription
        }
    }

    /// Genera gli outfit. Con `random` sceglie a caso tra i migliori dieci.
    private func generate(random: Bool) {
        let trimmed = freeText.trimmingCharacters(in: .whitespaces)
        // La descrizione libera vince sul menu, se riconosce un'occasione; altrimenti vale il menu.
        let chosen = trimmed.isEmpty ? occasion : (Occasion.inferred(from: trimmed) ?? occasion)
        let rain = weather?.isRaining ?? false
        let ctx = OutfitEngine.context(
            occasion: chosen, season: season, temperature: temperature, isRaining: rain,
            rated: savedOutfits, preferredStyle: preferredStyle
        )
        let result = OutfitEngine.suggest(from: garments.map(GarmentSnapshot.init), context: ctx, count: random ? 10 : 3)
        let picked = random ? (result.outfits.randomElement().map { [$0] } ?? []) : result.outfits
        results = picked.map { s in
            StylistResult(
                suggestion: s,
                session: OutfitSession(suggestion: s, occasion: chosen, season: season, temperature: temperature, isRaining: rain)
            )
        }
        missing = result.missing
        searched = true
    }
}
