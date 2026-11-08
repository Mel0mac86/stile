import XCTest
@testable import MyWardrobeAI

/// Test del motore di abbinamento, dei colori e dell'occasione.
/// Usano solo capi creati nel test: nessun dato fittizio nell'app.
final class OutfitEngineTests: XCTestCase {

    /// Crea un capo con colore dalla palette e stile dato.
    private func make(_ name: String, _ category: GarmentCategory, color: String = "Nero",
                      style: GarmentStyle = .casual, seasons: [String] = [Season.allSeasonsTag],
                      material: String = "") -> GarmentSnapshot {
        var draft = GarmentDraft()
        draft.name = name
        draft.category = category
        draft.colorName = color
        if let entry = ColorAnalysis.paletteEntry(named: color) {
            draft.hue = entry.color.hue
            draft.saturation = entry.color.saturation
            draft.brightness = entry.color.brightness
        }
        draft.style = style.rawValue
        draft.seasons = seasons
        draft.material = material
        return GarmentSnapshot(Garment(draft: draft))
    }

    func testNeutralColorsMatchEverything() {
        let black = HSBColor(hue: 0, saturation: 0, brightness: 0.1)
        let red = HSBColor(hue: 0, saturation: 0.8, brightness: 0.8)
        XCTAssertGreaterThanOrEqual(ColorAnalysis.harmony(black, red), 0.9)
    }

    func testComplementaryColorsAreHarmonious() {
        let blue = HSBColor(hue: 0.61, saturation: 0.7, brightness: 0.7)
        let orange = HSBColor(hue: 0.07, saturation: 0.8, brightness: 0.95)
        XCTAssertGreaterThanOrEqual(ColorAnalysis.harmony(blue, orange), 0.75)
    }

    func testMissingShoesIsReported() {
        let garments = [make("Maglia", .tshirt), make("Jeans", .jeans)]
        let result = OutfitEngine.suggest(from: garments, context: OutfitContext())
        XCTAssertTrue(result.outfits.isEmpty)
        XCTAssertTrue(result.missing.contains { $0.contains("scarpe") })
    }

    func testOutfitsUseOnlyOwnedItems() {
        let garments = [
            make("Camicia", .shirt, color: "Azzurro", style: .smartCasual),
            make("Chino", .trousers, color: "Beige", style: .smartCasual),
            make("Derby", .shoes, color: "Marrone", style: .elegant),
            make("Sneakers", .sneakers, color: "Bianco", style: .casual)
        ]
        let ids = Set(garments.map(\.id))
        let result = OutfitEngine.suggest(from: garments, context: OutfitContext())
        XCTAssertFalse(result.outfits.isEmpty)
        for outfit in result.outfits {
            XCTAssertTrue(Set(outfit.items.map(\.id)).isSubset(of: ids))
        }
    }

    func testSuggestsDifferentOutfits() {
        let garments = [
            make("T1", .tshirt, color: "Bianco"), make("T2", .tshirt, color: "Nero"),
            make("P1", .jeans, color: "Blu"), make("P2", .trousers, color: "Grigio"),
            make("S1", .sneakers, color: "Bianco"), make("S2", .boots, color: "Marrone")
        ]
        let result = OutfitEngine.suggest(from: garments, context: OutfitContext(), count: 3)
        XCTAssertEqual(result.outfits.count, 3)
        let sets = result.outfits.map { Set($0.items.map(\.id)) }
        XCTAssertEqual(Set(sets.map { $0.sorted { $0.uuidString < $1.uuidString } .map(\.uuidString).joined() }).count, 3)
    }

    func testColdWeatherWarnsWithoutOuterwear() {
        var context = OutfitContext()
        context.temperature = 2
        let garments = [make("Maglia", .tshirt), make("Pantaloni", .trousers), make("Scarpe", .shoes)]
        let result = OutfitEngine.suggest(from: garments, context: context)
        XCTAssertTrue(result.missing.contains { $0.contains("giacca") || $0.contains("cappotto") })
    }

    func testOccasionIsInferredFromFreeText() {
        XCTAssertEqual(Occasion.inferred(from: "festa in terrazza"), .party)
        XCTAssertEqual(Occasion.inferred(from: "colloquio domani"), .jobInterview)
        XCTAssertNil(Occasion.inferred(from: "xyz"))
    }

    func testLearnedRatingsShiftScores() {
        let outfit = SavedOutfit(title: "A", occasion: .work, itemIDs: [UUID()], reasons: [], isFavorite: false, rating: 5)
        let scores = PreferenceLearner.itemScores(from: [outfit])
        XCTAssertEqual(scores.values.first ?? 0, 1, accuracy: 0.0001)
    }

    func testPackingWarnsWhenItemsMissing() {
        let plan = PackingPlanner.plan(garments: [], days: 3, context: OutfitContext())
        XCTAssertTrue(plan.items.isEmpty)
        XCTAssertFalse(plan.warnings.isEmpty)
    }
}
