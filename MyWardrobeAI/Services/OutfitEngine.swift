import Foundation

/// Copia leggera di un capo: il motore lavora su questi valori, non sugli oggetti SwiftData.
struct GarmentSnapshot: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: GarmentCategory
    let color: HSBColor
    let colorName: String
    let seasons: [String]
    /// Eleganza 1...5: dallo stile scelto, o dalla categoria se lo stile manca.
    let formality: Int
    /// Calore 1...5, dalla categoria.
    let warmth: Int
    /// Impermeabile: deduce dal materiale ("impermeabile", "Gore-Tex").
    let isWaterproof: Bool
    let lastWornDate: Date?
    let photoFileName: String
    let cutoutFileName: String

    var slot: OutfitSlot { category.slot }

    init(_ g: Garment) {
        id = g.id
        name = g.name
        category = g.category
        color = g.color
        colorName = g.colorName
        seasons = g.seasons
        formality = GarmentStyle(rawValue: g.style)?.formality ?? g.category.defaultFormality
        warmth = g.category.warmth
        let material = g.material.lowercased()
        isWaterproof = material.contains("impermeab") || material.contains("gore")
        lastWornDate = g.lastWornDate
        photoFileName = g.photoFileName
        cutoutFileName = g.cutoutFileName
    }
}

/// Condizioni in cui cercare un outfit.
struct OutfitContext {
    var occasion: Occasion = .leisure
    var season: Season = .current
    /// Temperatura in °C, se nota (meteo o impostata a mano).
    var temperature: Double? = nil
    var isRaining = false
    /// Livello di eleganza preferito dall'utente (profilo).
    var preferredFormality: Int? = nil
    /// Punteggio appreso per ogni capo, da -1 a +1, dalle valutazioni degli outfit.
    var itemScores: [UUID: Double] = [:]
    /// Capi da escludere dai suggerimenti.
    var excluded: Set<UUID> = []

    var targetWarmth: Int { OutfitEngine.targetWarmth(temperature: temperature, season: season) }
}

/// Un outfit proposto: i capi scelti, il punteggio (0...1), i motivi e gli avvisi.
struct OutfitSuggestion: Identifiable {
    let id = UUID()
    let items: [GarmentSnapshot]
    let score: Double
    /// Perché i capi stanno bene insieme.
    let reasons: [String]
    /// Consigli o dubbi (es. "Fa freddo: manca una giacca").
    let warnings: [String]
}

/// Risultato di una ricerca: gli outfit possibili e i capi mancanti da segnalare.
struct SuggestionResult {
    let outfits: [OutfitSuggestion]
    let missing: [String]
}

/// Alternativa per sostituire un solo capo.
struct OutfitAlternative: Identifiable {
    let garment: GarmentSnapshot
    let score: Double
    var id: UUID { garment.id }
}

/// Motore di abbinamento: usa solo i capi che l'utente possiede. Non inventa capi.
/// È deterministico: stessi capi e stesso contesto producono sempre gli stessi outfit.
enum OutfitEngine {
    /// Quanti capi per categoria entrano nella combinazione (limita il numero di combinazioni).
    static let pool = 12

    /// Calore richiesto: dalla temperatura se è nota, altrimenti dalla stagione.
    static func targetWarmth(temperature: Double?, season: Season) -> Int {
        guard let t = temperature else { return season.warmth }
        switch t {
        case ..<5: return 5
        case ..<12: return 4
        case ..<18: return 3
        case ..<24: return 2
        default: return 1
        }
    }

    /// Cerca fino a `count` outfit diversi tra loro, con i capi segnalati se mancano.
    static func suggest(from garments: [GarmentSnapshot], context c: OutfitContext, count: Int = 3) -> SuggestionResult {
        let usable = garments.filter { !c.excluded.contains($0.id) }
        func bySlot(_ slot: OutfitSlot) -> [GarmentSnapshot] {
            rank(usable.filter { $0.slot == slot }, c)
        }
        let tops = bySlot(.top)
        let dresses = bySlot(.dress)
        let bottoms = bySlot(.bottom)
        let shoes = bySlot(.shoes)
        let outers = bySlot(.outerwear)
        let accessories = bySlot(.accessory)
        let needsOuter = c.targetWarmth >= 4 || c.isRaining

        // Segnala i capi mancanti in modo esplicito, come chiede la specifica.
        var missing: [String] = []
        if tops.isEmpty && dresses.isEmpty { missing.append("Manca una maglia, camicia o polo (oppure un abito)") }
        if bottoms.isEmpty && dresses.isEmpty { missing.append("Manca un paio di pantaloni, jeans o una gonna (oppure un abito)") }
        if shoes.isEmpty { missing.append("Manca un paio di scarpe") }
        if needsOuter && outers.isEmpty {
            missing.append(c.isRaining ? "Manca una giacca impermeabile per la pioggia" : "Manca una giacca o un cappotto per il freddo")
        }

        // Basi: un abito da solo, oppure una coppia maglia + pantalone.
        var bases: [[GarmentSnapshot]] = dresses.prefix(pool).map { [$0] }
        for top in tops.prefix(pool) {
            for bottom in bottoms.prefix(pool) {
                bases.append([top, bottom])
            }
        }
        guard !bases.isEmpty, !shoes.isEmpty else {
            return SuggestionResult(outfits: [], missing: missing)
        }

        var outerOptions: [GarmentSnapshot?] = [nil]
        outerOptions += outers.prefix(6).map { Optional($0) }

        // Valuta tutte le combinazioni; per ognuna sceglie l'accessorio migliore (o nessuno).
        var candidates: [OutfitSuggestion] = []
        for base in bases {
            for shoe in shoes.prefix(8) {
                for outer in outerOptions {
                    let core = base + [shoe] + (outer.map { [$0] } ?? [])
                    var best = evaluate(core, context: c)
                    for accessory in accessories.prefix(4) {
                        let candidate = evaluate(core + [accessory], context: c)
                        if candidate.score > best.score { best = candidate }
                    }
                    candidates.append(best)
                }
            }
        }
        candidates.sort { $0.score > $1.score }

        // Prima cerca outfit che differiscono di almeno 2 capi; poi riempie con varianti.
        var picked: [OutfitSuggestion] = []
        for strictness in [2, 1] where picked.count < count {
            for candidate in candidates where picked.count < count {
                let ids = Set(candidate.items.map(\.id))
                let tooSimilar = picked.contains { p in
                    Set(p.items.map(\.id)).intersection(ids).count > ids.count - strictness
                }
                if !tooSimilar { picked.append(candidate) }
            }
        }
        return SuggestionResult(outfits: picked, missing: missing)
    }

    /// Punteggio di un insieme di capi nel contesto dato, con motivi e avvisi.
    static func evaluate(_ items: [GarmentSnapshot], context c: OutfitContext) -> OutfitSuggestion {
        let ordered = items.sorted { $0.slot.rawValue < $1.slot.rawValue }
        let clothing = ordered.filter { $0.slot != .accessory }
        let target = c.targetWarmth
        var reasons: [String] = []
        var warnings: [String] = []

        // 1. Colori: media dell'armonia di tutte le coppie di capi.
        var pairs: [Double] = []
        for i in clothing.indices {
            for j in clothing.indices where j > i {
                pairs.append(ColorAnalysis.harmony(clothing[i].color, clothing[j].color))
            }
        }
        let colorScore = pairs.isEmpty ? 0.8 : pairs.reduce(0, +) / Double(pairs.count)

        // 2. Eleganza: capi coerenti tra loro e adatti all'occasione.
        let levels = clothing.map { Double($0.formality) }
        let meanLevel = levels.isEmpty ? 0 : levels.reduce(0, +) / Double(levels.count)
        let spread = (levels.max() ?? 0) - (levels.min() ?? 0)
        let occasionFit = max(0, 1 - abs(meanLevel - Double(c.occasion.formality)) * 0.25)
        let coherence = max(0, 1 - spread * 0.2)
        let styleScore = 0.6 * occasionFit + 0.4 * coherence

        // 3. Temperatura e stagione.
        let warmthFits = clothing.map { 1 - min(1, abs(Double($0.warmth - target)) * 0.25) }
        let weatherScore = warmthFits.isEmpty ? 0 : warmthFits.reduce(0, +) / Double(warmthFits.count)
        let outOfSeason = items.filter { !fitsSeason($0, c.season) }.count
        let hasOuter = ordered.contains { $0.slot == .outerwear }
        if clothing.contains(where: { $0.warmth < target - 1 }) {
            warnings.append("Potrebbe essere troppo leggero per la temperatura")
        }
        if clothing.contains(where: { $0.warmth > target + 1 }) {
            warnings.append("Potrebbe essere troppo pesante per il clima")
        }
        if target >= 4 && !hasOuter {
            warnings.append("Fa freddo: aggiungi una giacca o un cappotto")
        }
        if outOfSeason > 0 {
            warnings.append("\(outOfSeason) capo/i non tipici della stagione")
        }

        // 4. Pioggia: premia capi impermeabili.
        var rainBonus = 0.0
        if c.isRaining {
            if ordered.contains(where: { $0.slot == .outerwear && $0.isWaterproof }) { rainBonus += 0.1 }
            if ordered.contains(where: { $0.slot == .shoes && $0.isWaterproof }) { rainBonus += 0.05 }
        }

        // 5. Preferenze: valutazioni passate e stile preferito nel profilo.
        let learned = items.isEmpty ? 0 : items.reduce(0.0) { $0 + (c.itemScores[$1.id] ?? 0) } / Double(items.count)
        var profileBonus = 0.0
        if let preferred = c.preferredFormality, abs(meanLevel - Double(preferred)) < 1 {
            profileBonus = 0.05
        }

        // 6. Varietà: premia i capi non indossati da una settimana.
        let resting = Double(items.filter { isResting($0.lastWornDate) }.count) / Double(max(items.count, 1))

        // Pesi: colori 40%, stile 30%, meteo 30%, più i bonus e le penalità (spezzato per il type-checker).
        let base: Double = 0.4 * colorScore + 0.3 * styleScore + 0.3 * weatherScore
        let bonus: Double = rainBonus + 0.15 * learned + profileBonus + 0.05 * resting
        let penalty: Double = Double(outOfSeason) * 0.1
        let raw: Double = base + bonus - penalty
        let score: Double = min(1, max(0, raw))

        if colorScore >= 0.75 { reasons.append("I colori si armonizzano bene") }
        if colorScore < 0.5 { warnings.append("Colori un po' contrastanti: un capo neutro li ammorbidirebbe") }
        if occasionFit >= 0.8 { reasons.append("Adatto a: \(c.occasion.rawValue.lowercased())") }
        if coherence >= 0.8 { reasons.append("Capi con lo stesso livello di eleganza") }
        if weatherScore >= 0.75 { reasons.append("Adatto alla temperatura prevista") }
        if outOfSeason == 0 { reasons.append("Tutti i capi sono adatti a \(c.season.rawValue.lowercased())") }
        if rainBonus > 0 { reasons.append("Include capi impermeabili per la pioggia") }
        if learned > 0.2 { reasons.append("Simile agli outfit che hai valutato bene") }
        if reasons.isEmpty { reasons.append("Combinazione valida con i capi che hai") }

        return OutfitSuggestion(items: ordered, score: score, reasons: reasons, warnings: warnings)
    }

    /// Alternative per sostituire un capo, mantenendo gli altri. Ordinate per punteggio.
    static func alternatives(replacing item: GarmentSnapshot, in current: [GarmentSnapshot],
                             from garments: [GarmentSnapshot], context c: OutfitContext) -> [OutfitAlternative] {
        let rest = current.filter { $0.id != item.id }
        return garments
            .filter { $0.slot == item.slot && $0.id != item.id && !c.excluded.contains($0.id) }
            .map { OutfitAlternative(garment: $0, score: evaluate(rest + [$0], context: c).score) }
            .sorted { $0.score > $1.score }
    }

    /// Ordinamento di un singolo capo: meteo, stagione, stile e valutazioni passate.
    static func individualScore(_ g: GarmentSnapshot, _ c: OutfitContext) -> Double {
        var s = 1 - min(1, abs(Double(g.warmth - c.targetWarmth)) * 0.25)
        if fitsSeason(g, c.season) { s += 0.3 }
        s -= abs(Double(g.formality - c.occasion.formality)) * 0.05
        s += 0.2 * (c.itemScores[g.id] ?? 0)
        return s
    }

    static func fitsSeason(_ g: GarmentSnapshot, _ season: Season) -> Bool {
        g.seasons.contains(season.rawValue) || g.seasons.contains(Season.allSeasonsTag)
    }

    /// true se il capo non è stato indossato negli ultimi 7 giorni (o non è mai stato indossato).
    static func isResting(_ last: Date?) -> Bool {
        guard let date = last else { return true }
        return date < Date().addingTimeInterval(-7 * 86_400)
    }

    private static func rank(_ list: [GarmentSnapshot], _ c: OutfitContext) -> [GarmentSnapshot] {
        list.sorted { individualScore($0, c) > individualScore($1, c) }
    }

    /// Crea il contesto a partire dai dati dell'app (salvati, profilo, meteo).
    static func context(occasion: Occasion, season: Season, temperature: Double?, isRaining: Bool,
                        rated: [SavedOutfit], preferredStyle: String) -> OutfitContext {
        var c = OutfitContext()
        c.occasion = occasion
        c.season = season
        c.temperature = temperature
        c.isRaining = isRaining
        c.itemScores = PreferenceLearner.itemScores(from: rated)
        c.preferredFormality = GarmentStyle(rawValue: preferredStyle)?.formality
        return c
    }
}

/// Apprendimento delle preferenze: ogni valutazione sposta i punteggi dei capi di quell'outfit.
enum PreferenceLearner {
    /// 1★ = -1, 3★ = 0, 5★ = +1. Per ogni capo si fa la media delle valutazioni ricevute.
    static func itemScores(from outfits: [SavedOutfit]) -> [UUID: Double] {
        var sums: [UUID: Double] = [:]
        var counts: [UUID: Double] = [:]
        for outfit in outfits where outfit.rating > 0 {
            let value = Double(outfit.rating - 3) / 2
            for id in outfit.itemUUIDs {
                sums[id, default: 0] += value
                counts[id, default: 0] += 1
            }
        }
        var result: [UUID: Double] = [:]
        for (id, total) in sums {
            result[id] = total / counts[id, default: 1]
        }
        return result
    }
}
