import SwiftUI
import SwiftData

/// Dettaglio di un outfit: composizione grafica, motivi, valutazione, sostituzione dei singoli capi.
struct OutfitDetailView: View {
    let session: OutfitSession

    @Environment(\.modelContext) private var context
    @Query(sort: \Garment.dateAdded) private var garments: [Garment]
    @Query private var savedOutfits: [SavedOutfit]
    @AppStorage(AppSettings.preferredStyleKey) private var preferredStyle = ""

    @State private var itemIDs: [UUID]
    @State private var savedID: UUID?
    @State private var replacing: GarmentSnapshot?
    @State private var message: String?

    init(session: OutfitSession) {
        self.session = session
        _itemIDs = State(initialValue: session.itemIDs)
        _savedID = State(initialValue: session.savedID)
    }

    /// Capi dell'outfit, nell'ordine di composizione. Se un capo è stato eliminato, non compare.
    private var snapshots: [GarmentSnapshot] {
        itemIDs.compactMap { id in garments.first { $0.id == id }.map(GarmentSnapshot.init) }
    }

    private var allSnapshots: [GarmentSnapshot] {
        garments.map(GarmentSnapshot.init)
    }

    private var saved: SavedOutfit? {
        savedOutfits.first { $0.id == savedID }
    }

    private var outfitContext: OutfitContext {
        OutfitEngine.context(
            occasion: session.occasion, season: session.season, temperature: session.temperature,
            isRaining: session.isRaining, rated: savedOutfits, preferredStyle: preferredStyle
        )
    }

    var body: some View {
        let evaluation = OutfitEngine.evaluate(snapshots, context: outfitContext)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OutfitCompositionView(items: snapshots)

                VStack(alignment: .leading, spacing: 8) {
                    ScoreBadge(score: evaluation.score)
                    Text("Perché stanno bene insieme").font(.headline).padding(.top, 4)
                    ForEach(evaluation.reasons, id: \.self) { reason in
                        Label(reason, systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(evaluation.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Capi").font(.headline)
                    ForEach(snapshots) { item in
                        HStack(spacing: 12) {
                            GarmentImage(cutout: item.cutoutFileName, photo: item.photoFileName)
                                .frame(width: 70, height: 84)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.subheadline.weight(.semibold))
                                Text("\(item.category.title) · \(item.colorName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Sostituisci") { replacing = item }
                                .buttonStyle(.bordered)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Valutazione").font(.headline)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                ensureSaved().rating = star
                            } label: {
                                Image(systemName: star <= (saved?.rating ?? 0) ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(.yellow)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(star) stelle")
                        }
                    }
                    Text("Più valuti, più i suggerimenti imparano i tuoi gusti.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Button {
                        wearToday()
                    } label: {
                        Label("Indossato oggi", systemImage: "calendar.badge.checkmark")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(snapshots.isEmpty)

                    Button {
                        toggleFavorite()
                    } label: {
                        Label((saved?.isFavorite ?? false) ? "Rimuovi dai preferiti" : "Salva nei preferiti",
                              systemImage: (saved?.isFavorite ?? false) ? "heart.slash" : "heart")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }

                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $replacing) { item in
            ReplacementSheet(
                item: item,
                options: OutfitEngine.alternatives(replacing: item, in: snapshots, from: allSnapshots, context: outfitContext)
            ) { picked in
                replace(item, with: picked)
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// Sostituisce un capo mantenendo gli altri, e aggiorna l'outfit salvato se esiste.
    private func replace(_ old: GarmentSnapshot, with new: GarmentSnapshot) {
        if let index = itemIDs.firstIndex(of: old.id) {
            itemIDs[index] = new.id
        }
        saved?.itemIDs = itemIDs.map(\.uuidString)
        message = "Sostituito: \(old.name) → \(new.name)"
    }

    /// Crea la voce in cronologia la prima volta che l'utente interagisce con l'outfit.
    @discardableResult
    private func ensureSaved() -> SavedOutfit {
        if let existing = saved { return existing }
        let created = SavedOutfit(
            title: session.title, occasion: session.occasion, itemIDs: itemIDs,
            reasons: OutfitEngine.evaluate(snapshots, context: outfitContext).reasons, isFavorite: false
        )
        context.insert(created)
        savedID = created.id
        return created
    }

    private func toggleFavorite() {
        let outfit = ensureSaved()
        outfit.isFavorite.toggle()
        message = outfit.isFavorite ? "Aggiunto ai preferiti" : "Rimosso dai preferiti"
    }

    /// Registra l'outfit nel calendario e aggiorna data e conteggio di ogni capo.
    private func wearToday() {
        ensureSaved()
        context.insert(WearEntry(title: session.title, itemIDs: itemIDs))
        for garment in garments where itemIDs.contains(garment.id) {
            garment.lastWornDate = .now
            garment.wearCount += 1
        }
        message = "Registrato nel calendario di oggi"
    }
}

/// Scelta di un capo alternativo, con il punteggio che avrebbe l'outfit.
struct ReplacementSheet: View {
    let item: GarmentSnapshot
    let options: [OutfitAlternative]
    let onPick: (GarmentSnapshot) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if options.isEmpty {
                    Text("Non hai altri capi nella categoria \(item.category.title.lowercased()). Aggiungine uno nel guardaroba.")
                        .foregroundStyle(.secondary)
                }
                ForEach(options) { option in
                    Button {
                        onPick(option.garment)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            GarmentImage(cutout: option.garment.cutoutFileName, photo: option.garment.photoFileName)
                                .frame(width: 60, height: 72)
                            VStack(alignment: .leading) {
                                Text(option.garment.name).font(.subheadline.weight(.semibold))
                                Text(option.garment.colorName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(option.score * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Sostituisci capo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}
