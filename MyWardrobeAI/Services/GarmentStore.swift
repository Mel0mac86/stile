import Foundation
import SwiftData

/// Salvataggio ed eliminazione dei capi: scrive i file delle foto e poi aggiorna il database.
enum GarmentStore {
    /// Crea un capo nuovo (existing == nil) oppure aggiorna quello esistente.
    static func save(_ draft: GarmentDraft, existing: Garment?, context: ModelContext) throws {
        var d = draft
        if let photo = d.pendingPhoto {
            let newName = try ImageStore.write(photo, ext: "jpg")
            ImageStore.delete(d.photoFileName)   // rimuove la foto precedente, se c'era
            d.photoFileName = newName
            d.pendingPhoto = nil
        }
        if let cutout = d.pendingCutout {
            let newName = try ImageStore.write(cutout, ext: "png")
            ImageStore.delete(d.cutoutFileName)
            d.cutoutFileName = newName
            d.pendingCutout = nil
        }
        if let garment = existing {
            garment.update(from: d)
        } else {
            context.insert(Garment(draft: d))
        }
        try context.save()
    }

    static func delete(_ garment: Garment, context: ModelContext) throws {
        ImageStore.delete(garment.photoFileName)
        ImageStore.delete(garment.cutoutFileName)
        context.delete(garment)
        try context.save()
    }
}
