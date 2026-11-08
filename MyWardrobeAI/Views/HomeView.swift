import SwiftUI
import SwiftData

/// Home: saluto, meteo (con consenso), capi dimenticati e outfit del giorno.
struct HomeView: View {
    @Query(sort: \Garment.dateAdded) private var garments: [Garment]
    @Query private var savedOutfits: [SavedOutfit]
    @AppStorage(AppSettings.weatherConsentKey) private var weatherConsent = false
    @AppStorage(AppSettings.preferredStyleKey) private var preferredStyle = ""

    @State private var weatherService = WeatherService()
    @State private var weather: WeatherService.Current?
    @State private var weatherMessage: String?
    @State private var loadingWeather = false
    @State private var suggestion: OutfitSuggestion?
    @State private var missing: [String] = []

    private var unusedCount: Int {
        garments.filter(\.isUnused).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    greeting
                    if weatherConsent {
                        weatherCard
                    }
                    if unusedCount > 0 {
                        unusedBanner
                    }
                    outfitOfTheDay
                }
                .padding()
            }
            .navigationTitle("Home")
            .navigationDestination(for: OutfitSession.self) { OutfitDetailView(session: $0) }
            .task(id: weatherConsent) {
                await refreshWeather()
            }
            .onChange(of: garments.count) { _, _ in
                regenerate()
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText).font(.title2.bold())
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var greetingText: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<13: return "Buongiorno"
        case 13..<18: return "Buon pomeriggio"
        default: return "Buonasera"
        }
    }

    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let w = weather {
                HStack(spacing: 12) {
                    Image(systemName: w.isRaining ? "cloud.rain.fill" : "sun.max.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.multicolor)
                    VStack(alignment: .leading) {
                        Text("\(Int(w.temperature.rounded()))°C").font(.title2.bold())
                        Text(w.isRaining ? "Pioggia in corso" : "Senza pioggia")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Vento \(Int(w.windSpeed)) km/h\nUmidità \(Int(w.humidity))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            } else if let message = weatherMessage {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            } else {
                Text(loadingWeather ? "Leggo il meteo…" : "Meteo non disponibile")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Aggiorna meteo") {
                Task { await refreshWeather() }
            }
            .font(.footnote)
            .disabled(loadingWeather)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var unusedBanner: some View {
        Label("\(unusedCount) capi non indossati da più di \(Garment.unusedThresholdDays) giorni: prova a rimetterli in gioco.",
              systemImage: "clock.arrow.circlepath")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var outfitOfTheDay: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Outfit del giorno").font(.title3.bold())
            if garments.isEmpty {
                ContentUnavailableView(
                    "Guardaroba vuoto",
                    systemImage: "hanger",
                    description: Text("Aggiungi i tuoi capi: l'app ti proporrà gli abbinamenti.")
                )
            } else if let s = suggestion {
                OutfitCompositionView(items: s.items, height: 300)
                ScoreBadge(score: s.score)
                ForEach(s.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(s.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                NavigationLink(value: OutfitSession(
                    suggestion: s, occasion: .leisure, season: .current,
                    temperature: weather?.temperature, isRaining: weather?.isRaining ?? false
                )) {
                    Label("Dettagli e sostituzioni", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            } else {
                ForEach(missing, id: \.self) { item in
                    Label(item, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    /// Legge il meteo solo se l'utente ha dato il consenso.
    private func refreshWeather() async {
        guard weatherConsent else {
            weather = nil
            weatherMessage = nil
            regenerate()
            return
        }
        loadingWeather = true
        defer { loadingWeather = false }
        do {
            weather = try await weatherService.loadCurrentWeather()
            weatherMessage = nil
        } catch {
            weatherMessage = error.localizedDescription
        }
        regenerate()
    }

    /// Outfit del giorno: tra i migliori tre, ruota ogni giorno dell'anno.
    private func regenerate() {
        let ctx = OutfitEngine.context(
            occasion: .leisure, season: .current,
            temperature: weather?.temperature, isRaining: weather?.isRaining ?? false,
            rated: savedOutfits, preferredStyle: preferredStyle
        )
        let result = OutfitEngine.suggest(from: garments.map(GarmentSnapshot.init), context: ctx, count: 3)
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        suggestion = result.outfits.isEmpty ? nil : result.outfits[day % result.outfits.count]
        missing = result.missing
    }
}
