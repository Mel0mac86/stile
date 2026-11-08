import Foundation

/// Crea la valigia: quanti capi servono per la durata del viaggio, scelti dal guardaroba.
enum PackingPlanner {
    struct Plan {
        /// Capi da mettere in valigia, nell'ordine di scelta.
        let items: [GarmentSnapshot]
        /// Cosa manca nel guardaroba per coprire il viaggio.
        let warnings: [String]
    }

    static func plan(garments: [GarmentSnapshot], days: Int, context c: OutfitContext) -> Plan {
        let d = max(1, days)
        // Maglie: una al giorno per brevi viaggi, poi si ricicla (si lavano).
        let tops = d <= 4 ? d : (d + 1) / 2 + 1
        // Pantaloni: uno ogni tre giorni circa.
        let bottoms = max(1, Int((Double(d) / 3).rounded(.up)))

        var chosen: [GarmentSnapshot] = []
        var warnings: [String] = []

        // Sceglie `count` capi dello slot, uno alla volta, privilegiando quelli che stanno bene con i già scelti.
        func pick(_ slot: OutfitSlot, _ count: Int, _ label: String, required: Bool) {
            var pool = garments.filter { $0.slot == slot && !c.excluded.contains($0.id) }
            var taken = 0
            while taken < count, !pool.isEmpty {
                let snapshot = chosen
                guard let best = pool.max(by: { packScore($0, snapshot, c) < packScore($1, snapshot, c) }) else { break }
                chosen.append(best)
                pool.removeAll { $0.id == best.id }
                taken += 1
            }
            if taken < count && required {
                warnings.append("Mancano \(count - taken) \(label): aggiungili al guardaroba o accorcia il viaggio")
            }
        }

        pick(.top, tops, "maglie o camicie", required: true)
        pick(.bottom, bottoms, "pantaloni o gonne", required: true)
        pick(.shoes, 2, "paia di scarpe", required: true)
        if c.targetWarmth >= 3 {
            pick(.outerwear, 1, "giacche o cappotti", required: true)
        }
        if d >= 3 && c.occasion.formality >= 4 {
            pick(.dress, 1, "abiti", required: false)
        }
        pick(.accessory, 2, "accessori", required: false)

        return Plan(items: chosen, warnings: warnings)
    }

    /// Punteggio di un capo rispetto a quelli già in valigia: adattamento al clima e armonia di colore.
    private static func packScore(_ g: GarmentSnapshot, _ others: [GarmentSnapshot], _ c: OutfitContext) -> Double {
        let clothing = others.filter { $0.slot != .accessory }
        var harmony = 0.5
        if !clothing.isEmpty {
            let values = clothing.map { ColorAnalysis.harmony(g.color, $0.color) }
            harmony = values.reduce(0, +) / Double(values.count)
        }
        return OutfitEngine.individualScore(g, c) + 0.5 * harmony
    }
}
