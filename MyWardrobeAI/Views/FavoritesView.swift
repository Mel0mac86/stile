import SwiftUI
import SwiftData

/// Sezioni di Preferiti: outfit salvati, cronologia completa e calendario dei giorni indossati.
enum FavoritesTab: String, CaseIterable, Identifiable {
    case favorites = "Preferiti"
    case history = "Cronologia"
    case calendar = "Calendario"

    var id: String { rawValue }
}

struct FavoritesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedOutfit.createdAt, order: .reverse) private var outfits: [SavedOutfit]
    @Query(sort: \WearEntry.date, order: .reverse) private var wears: [WearEntry]
    @Query(sort: \Garment.dateAdded) private var garments: [Garment]
    @State private var tab: FavoritesTab = .favorites
    @State private var selectedDay = Date()

    /// Accesso rapido ai capi per id, per mostrare le foto negli elenchi.
    private var lookup: [UUID: GarmentSnapshot] {
        Dictionary(uniqueKeysWithValues: garments.map { ($0.id, GarmentSnapshot($0)) })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Sezione", selection: $tab) {
                    ForEach(FavoritesTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch tab {
                case .favorites:
                    outfitList(outfits.filter { $0.isFavorite }, emptyText: "Nessun preferito. Apri un outfit e toccalo per salvarlo qui.")
                case .history:
                    outfitList(outfits, emptyText: "La cronologia si riempie quando salvi, valuti o indossi un outfit.")
                case .calendar:
                    calendarView
                }
            }
            .navigationTitle("Preferiti")
            .navigationDestination(for: OutfitSession.self) { OutfitDetailView(session: $0) }
        }
    }

    @ViewBuilder
    private func outfitList(_ list: [SavedOutfit], emptyText: String) -> some View {
        if list.isEmpty {
            ContentUnavailableView("Ancora niente", systemImage: "heart", description: Text(emptyText))
        } else {
            List {
                ForEach(list) { outfit in
                    NavigationLink(value: session(for: outfit)) {
                        SavedOutfitRow(outfit: outfit, lookup: lookup)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(list[index]) }
                }
            }
            .listStyle(.plain)
        }
    }

    private var calendarView: some View {
        let entries = wears.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
        return List {
            Section {
                DatePicker("Giorno", selection: $selectedDay, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            Section("Outfit indossati") {
                if entries.isEmpty {
                    Text("Nessun outfit registrato in questo giorno.").foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title).font(.headline)
                        Text("\(entry.itemUUIDs.count) capi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(entries[index]) }
                }
            }
        }
    }

    /// Apre un outfit salvato: i capi restano quelli salvati, quelli eliminati non compaiono.
    private func session(for outfit: SavedOutfit) -> OutfitSession {
        OutfitSession(
            title: outfit.title,
            itemIDs: outfit.itemUUIDs,
            occasion: outfit.occasion,
            season: .current,
            temperature: nil,
            isRaining: false,
            savedID: outfit.id,
            reasons: outfit.reasons
        )
    }
}
