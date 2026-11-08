import Foundation

// Port dei test di OutfitEngineTests: eseguibili fuori da Xcode.
var failures = 0
var passes = 0
func check(_ cond: @autoclosure () -> Bool, _ name: String) {
    if cond() { passes += 1; print("PASS  \(name)") } else { failures += 1; print("FAIL  \(name)") }
}

func make(_ name: String, _ category: GarmentCategory, color: String = "Nero", style: GarmentStyle = .casual,
          seasons: [String] = [Season.allSeasonsTag], material: String = "") -> GarmentSnapshot {
    var draft = GarmentDraft()
    draft.name = name
    draft.category = category
    draft.colorName = color
    if let entry = ColorAnalysis.paletteEntry(named: color) {
        draft.hue = entry.color.hue; draft.saturation = entry.color.saturation; draft.brightness = entry.color.brightness
    }
    draft.style = style.rawValue
    draft.seasons = seasons
    draft.material = material
    return GarmentSnapshot(Garment(draft: draft))
}

// 1. Colori neutri abbinano tutto
let black = HSBColor(hue: 0, saturation: 0, brightness: 0.1)
let red = HSBColor(hue: 0, saturation: 0.8, brightness: 0.8)
check(ColorAnalysis.harmony(black, red) >= 0.9, "neutral color matches everything")

// 2. Complementari (blu/arancio) armoniosi
let blue = HSBColor(hue: 0.61, saturation: 0.7, brightness: 0.7)
let orange = HSBColor(hue: 0.07, saturation: 0.8, brightness: 0.95)
check(ColorAnalysis.harmony(blue, orange) >= 0.75, "complementary colors are harmonious")

// 3. Scarpe mancanti segnalate
let noShoes = OutfitEngine.suggest(from: [make("Maglia", .tshirt), make("Jeans", .jeans)], context: OutfitContext())
check(noShoes.outfits.isEmpty && noShoes.missing.contains { $0.contains("scarpe") }, "missing shoes are reported, no outfit invented")

// 4. Solo capi posseduti
let owned = [
    make("Camicia", .shirt, color: "Azzurro", style: .smartCasual),
    make("Chino", .trousers, color: "Beige", style: .smartCasual),
    make("Derby", .shoes, color: "Marrone", style: .elegant),
    make("Sneakers", .sneakers, color: "Bianco", style: .casual)
]
let ownedIDs = Set(owned.map(\.id))
let r4 = OutfitEngine.suggest(from: owned, context: OutfitContext())
check(!r4.outfits.isEmpty && r4.outfits.allSatisfy { Set($0.items.map(\.id)).isSubset(of: ownedIDs) }, "outfits use only owned items")

// 5. Tre outfit diversi
let many = [
    make("T1", .tshirt, color: "Bianco"), make("T2", .tshirt, color: "Nero"),
    make("P1", .jeans, color: "Blu"), make("P2", .trousers, color: "Grigio"),
    make("S1", .sneakers, color: "Bianco"), make("S2", .boots, color: "Marrone")
]
let r5 = OutfitEngine.suggest(from: many, context: OutfitContext(), count: 3)
let keys = Set(r5.outfits.map { $0.items.map { $0.id.uuidString }.sorted().joined(separator: ",") })
check(r5.outfits.count == 3 && keys.count == 3, "three different outfits are proposed when wardrobe allows")

// 6. Freddo senza giacca: avviso
var cold = OutfitContext(); cold.temperature = 2
let r6 = OutfitEngine.suggest(from: [make("Maglia", .tshirt), make("Pantaloni", .trousers), make("Scarpe", .shoes)], context: cold)
check(r6.missing.contains { $0.contains("giacca") || $0.contains("cappotto") }, "cold weather without outerwear is flagged")

// 7. Occasione da testo libero
check(Occasion.inferred(from: "festa in terrazza") == .party, "free text occasion: festa")
check(Occasion.inferred(from: "colloquio domani") == .jobInterview, "free text occasion: colloquio")
check(Occasion.inferred(from: "xyz") == nil, "unknown free text returns nil")

// 8. Apprendimento dalle valutazioni
let rated = SavedOutfit(title: "A", occasion: .work, itemIDs: [UUID()], reasons: [], isFavorite: false, rating: 5)
check(abs((PreferenceLearner.itemScores(from: [rated]).values.first ?? 0) - 1) < 0.0001, "5-star rating gives +1 learned score")

// 9. Valigia senza capi: avvisi
let emptyPlan = PackingPlanner.plan(garments: [], days: 3, context: OutfitContext())
check(emptyPlan.items.isEmpty && !emptyPlan.warnings.isEmpty, "packing with empty wardrobe reports what is missing")

// 10. Valigia con capi: ciascun capo scelto è posseduto
let packable = [
    make("T1", .tshirt), make("T2", .tshirt), make("T3", .polo), make("P1", .trousers), make("P2", .jeans),
    make("S1", .sneakers), make("S2", .shoes), make("B", .bag)
]
let plan10 = PackingPlanner.plan(garments: packable, days: 6, context: OutfitContext())
let packIDs = Set(packable.map(\.id))
check(plan10.items.allSatisfy { packIDs.contains($0.id) } && plan10.items.count >= 5, "packing picks only owned items (\(plan10.items.count) items)")

// 11. Backup: un capo con foto nulla da leggere non rompe la codifica
let backupFile = BackupService.BackupFile(version: 1, exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
    garments: [BackupService.GarmentRecord(id: UUID(), name: "Maglia", category: "Magliette", subcategory: "", colorName: "Blu", secondaryColorName: "", hue: 0.6, saturation: 0.7, brightness: 0.7, pattern: "Tinta unita", seasons: ["Estate"], material: "cotone", brand: "", size: "M", style: "Casual", personalNotes: "", dateAdded: Date(timeIntervalSince1970: 1_600_000_000), lastWornDate: nil, wearCount: 2, photo: Data([1,2,3]), cutout: nil)],
    outfits: [], wears: [])
let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
let encoded = try! enc.encode(backupFile)
let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
let decoded = try! dec.decode(BackupService.BackupFile.self, from: encoded)
check(decoded.garments.count == 1 && decoded.garments[0].photo == Data([1,2,3]) && decoded.garments[0].name == "Maglia", "backup JSON round-trip keeps photo bytes and fields")

// 12. Rimozione sfondo / classificazione etichette
check(GarmentAnalyzer.category(for: "t-shirt") == .tshirt, "label t-shirt -> Magliette")
check(GarmentAnalyzer.category(for: "sweatshirt") == .sweatshirt, "label sweatshirt -> Felpe")
check(GarmentAnalyzer.category(for: "running shoe") == .shoes, "label shoe -> Scarpe")
check(GarmentAnalyzer.category(for: "shirt") == .shirt, "label shirt -> Camicie")
check(GarmentAnalyzer.category(for: "zebra") == nil, "unknown label -> nil (Altro)")

// 13. Colori: naming e stagione
check(ColorAnalysis.colorName(for: HSBColor(hue: 0.6, saturation: 0.7, brightness: 0.3)) == "Blu navy", "dark blue named Blu navy")
check(ColorAnalysis.colorName(for: HSBColor(hue: 0, saturation: 0, brightness: 0.95)) == "Bianco", "white named Bianco")
check(Season.of(DateComponents(calendar: .current, year: 2026, month: 7, day: 10).date!) == .summer, "July is Estate")

// 14. Temperatura -> calore richiesto
check(OutfitEngine.targetWarmth(temperature: 2, season: .summer) == 5, "2°C needs warmth 5")
check(OutfitEngine.targetWarmth(temperature: 30, season: .winter) == 1, "30°C needs warmth 1")
check(OutfitEngine.targetWarmth(temperature: nil, season: .winter) == 4, "no temperature: winter warmth 4")

// 15. Pioggia: capo impermeabile premiato
var rain = OutfitContext(); rain.isRaining = true; rain.temperature = 15
let coat = make("Impermeabile", .jacket, material: "impermeabile")
let plainCoat = make("Giacca", .jacket)
let top = make("Maglia", .tshirt), bottom = make("Pantaloni", .trousers), shoe = make("Scarpe", .shoes)
let withWP = OutfitEngine.evaluate([top, bottom, shoe, coat], context: rain).score
let withPlain = OutfitEngine.evaluate([top, bottom, shoe, plainCoat], context: rain).score
check(withWP > withPlain, "waterproof jacket scores higher when raining")

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
