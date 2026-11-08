import Foundation
import SwiftData

/// Backup ed esportazione: un unico file JSON con capi, foto, outfit e calendario.
/// Il file resta sotto il controllo dell'utente (lo salva dove preferisce, es. iCloud Drive).
enum BackupService {
    struct GarmentRecord: Codable {
        let id: UUID
        let name: String
        let category: String
        let subcategory: String
        let colorName: String
        let secondaryColorName: String
        let hue: Double
        let saturation: Double
        let brightness: Double
        let pattern: String
        let seasons: [String]
        let material: String
        let brand: String
        let size: String
        let style: String
        let personalNotes: String
        let dateAdded: Date
        let lastWornDate: Date?
        let wearCount: Int
        /// Foto originale e ritaglio, in byte (JSON le scrive in base64).
        let photo: Data?
        let cutout: Data?
    }

    struct OutfitRecord: Codable {
        let id: UUID
        let title: String
        let occasion: String
        let itemIDs: [String]
        let rating: Int
        let isFavorite: Bool
        let reasons: [String]
        let createdAt: Date
    }

    struct WearRecord: Codable {
        let id: UUID
        let date: Date
        let title: String
        let itemIDs: [String]
    }

    struct BackupFile: Codable {
        let version: Int
        let exportedAt: Date
        let garments: [GarmentRecord]
        let outfits: [OutfitRecord]
        let wears: [WearRecord]
    }

    /// Crea il backup in formato JSON.
    static func makeBackup(context: ModelContext) throws -> Data {
        let garments = try context.fetch(FetchDescriptor<Garment>())
        let outfits = try context.fetch(FetchDescriptor<SavedOutfit>())
        let wears = try context.fetch(FetchDescriptor<WearEntry>())

        let file = BackupFile(
            version: 1,
            exportedAt: Date(),
            garments: garments.map { g in
                GarmentRecord(
                    id: g.id, name: g.name, category: g.categoryRaw, subcategory: g.subcategory,
                    colorName: g.colorName, secondaryColorName: g.secondaryColorName,
                    hue: g.hue, saturation: g.saturation, brightness: g.brightness, pattern: g.pattern,
                    seasons: g.seasons, material: g.material, brand: g.brand, size: g.size,
                    style: g.style, personalNotes: g.personalNotes, dateAdded: g.dateAdded,
                    lastWornDate: g.lastWornDate, wearCount: g.wearCount,
                    photo: ImageStore.data(for: g.photoFileName),
                    cutout: ImageStore.data(for: g.cutoutFileName)
                )
            },
            outfits: outfits.map { o in
                OutfitRecord(
                    id: o.id, title: o.title, occasion: o.occasionRaw, itemIDs: o.itemIDs,
                    rating: o.rating, isFavorite: o.isFavorite, reasons: o.reasons, createdAt: o.createdAt
                )
            },
            wears: wears.map { w in
                WearRecord(id: w.id, date: w.date, title: w.title, itemIDs: w.itemIDs)
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(file)
    }

    /// Ripristina un backup. Gli elementi già presenti (stesso id) non vengono duplicati.
    static func restore(_ data: Data, context: ModelContext) throws -> (garments: Int, outfits: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)

        let existingGarments = Set(try context.fetch(FetchDescriptor<Garment>()).map(\.id))
        var addedGarments = 0
        for r in file.garments where !existingGarments.contains(r.id) {
            var draft = GarmentDraft()
            draft.id = r.id
            draft.name = r.name
            draft.category = GarmentCategory(rawValue: r.category) ?? .other
            draft.subcategory = r.subcategory
            draft.colorName = r.colorName
            draft.secondaryColorName = r.secondaryColorName
            draft.hue = r.hue
            draft.saturation = r.saturation
            draft.brightness = r.brightness
            draft.pattern = r.pattern
            draft.seasons = r.seasons
            draft.material = r.material
            draft.brand = r.brand
            draft.size = r.size
            draft.style = r.style
            draft.personalNotes = r.personalNotes
            draft.dateAdded = r.dateAdded
            draft.lastWornDate = r.lastWornDate
            draft.wearCount = r.wearCount
            draft.pendingPhoto = r.photo
            draft.pendingCutout = r.cutout
            try GarmentStore.save(draft, existing: nil, context: context)
            addedGarments += 1
        }

        let existingOutfits = Set(try context.fetch(FetchDescriptor<SavedOutfit>()).map(\.id))
        var addedOutfits = 0
        for o in file.outfits where !existingOutfits.contains(o.id) {
            let ids = o.itemIDs.compactMap { UUID(uuidString: $0) }
            context.insert(SavedOutfit(
                id: o.id, title: o.title, occasion: Occasion(rawValue: o.occasion) ?? .leisure,
                itemIDs: ids, reasons: o.reasons, isFavorite: o.isFavorite,
                rating: o.rating, createdAt: o.createdAt
            ))
            addedOutfits += 1
        }

        let existingWears = Set(try context.fetch(FetchDescriptor<WearEntry>()).map(\.id))
        for w in file.wears where !existingWears.contains(w.id) {
            context.insert(WearEntry(
                id: w.id, title: w.title,
                itemIDs: w.itemIDs.compactMap { UUID(uuidString: $0) }, date: w.date
            ))
        }
        try context.save()
        return (addedGarments, addedOutfits)
    }

    /// Cancella tutto: capi, foto, outfit salvati e calendario.
    static func deleteEverything(context: ModelContext) throws {
        for garment in try context.fetch(FetchDescriptor<Garment>()) { context.delete(garment) }
        for outfit in try context.fetch(FetchDescriptor<SavedOutfit>()) { context.delete(outfit) }
        for wear in try context.fetch(FetchDescriptor<WearEntry>()) { context.delete(wear) }
        try context.save()
        ImageStore.deleteAll()
    }
}
