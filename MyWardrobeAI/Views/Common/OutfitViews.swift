import SwiftUI

/// Striscia orizzontale con le foto dei capi di un outfit.
struct OutfitStrip: View {
    let items: [GarmentSnapshot]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                GarmentImage(cutout: item.cutoutFileName, photo: item.photoFileName)
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

/// Etichetta con il punteggio di armonia dell'outfit.
struct ScoreBadge: View {
    let score: Double

    var body: some View {
        Label("\(Int(score * 100))% armonia", systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}

/// Scheda di un outfit proposto dallo Stilista: foto, punteggio, motivi e avvisi.
struct OutfitCard: View {
    let title: String
    let suggestion: OutfitSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                ScoreBadge(score: suggestion.score)
            }
            OutfitStrip(items: suggestion.items)
            ForEach(suggestion.reasons.prefix(2), id: \.self) { reason in
                Label(reason, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(suggestion.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Riga di un outfit salvato (preferiti o cronologia).
struct SavedOutfitRow: View {
    let outfit: SavedOutfit
    let lookup: [UUID: GarmentSnapshot]

    var body: some View {
        let items = outfit.itemUUIDs.compactMap { lookup[$0] }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(outfit.title).font(.headline)
                Spacer()
                if outfit.isFavorite {
                    Image(systemName: "heart.fill").foregroundStyle(.pink)
                }
            }
            if !items.isEmpty {
                OutfitStrip(items: items)
            }
            HStack {
                Text(outfit.occasion.rawValue)
                Spacer()
                if outfit.rating > 0 {
                    Text(String(repeating: "★", count: outfit.rating))
                }
                Text(outfit.createdAt, style: .date)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Composizione grafica: i capi disposti come su un manichino, dall'alto verso il basso.
struct OutfitCompositionView: View {
    let items: [GarmentSnapshot]
    var height: CGFloat = 380

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                ForEach(items.sorted { $0.slot.rawValue < $1.slot.rawValue }) { item in
                    let place = layout(for: item.slot)
                    GarmentImage(cutout: item.cutoutFileName, photo: item.photoFileName)
                        .frame(width: geo.size.width * place.w, height: geo.size.height * place.h)
                        .position(x: geo.size.width * place.x, y: geo.size.height * place.y)
                }
            }
        }
        .frame(height: height)
    }

    /// Posizione e dimensione relative (0...1) di ogni slot nella composizione.
    private func layout(for slot: OutfitSlot) -> (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        switch slot {
        case .top: return (0.5, 0.27, 0.56, 0.3)
        case .dress: return (0.5, 0.36, 0.62, 0.5)
        case .bottom: return (0.5, 0.64, 0.46, 0.34)
        case .shoes: return (0.5, 0.9, 0.42, 0.14)
        case .outerwear: return (0.5, 0.25, 0.7, 0.36)
        case .accessory: return (0.84, 0.86, 0.24, 0.16)
        }
    }
}
