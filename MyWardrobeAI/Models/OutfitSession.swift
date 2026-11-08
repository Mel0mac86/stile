import Foundation

/// Un outfit aperto nella schermata di dettaglio. Valore semplice: si passa alla navigazione.
/// Il contesto (occasione, stagione, meteo) serve a ricalcolare le alternative di sostituzione.
struct OutfitSession: Hashable {
    var title: String
    var itemIDs: [UUID]
    var occasion: Occasion
    var season: Season
    var temperature: Double?
    var isRaining: Bool
    /// ID dell'outfit salvato, se esiste già in cronologia/preferiti.
    var savedID: UUID?
    var reasons: [String]
}

extension OutfitSession {
    /// Sessione per un outfit appena generato dal motore.
    init(suggestion s: OutfitSuggestion, occasion: Occasion, season: Season, temperature: Double?, isRaining: Bool) {
        self.init(
            title: "Outfit per \(occasion.rawValue.lowercased())",
            itemIDs: s.items.map(\.id),
            occasion: occasion,
            season: season,
            temperature: temperature,
            isRaining: isRaining,
            savedID: nil,
            reasons: s.reasons
        )
    }
}
