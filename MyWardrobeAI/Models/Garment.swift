import Foundation
import SwiftData

/// Capo del guardaroba (persistenza SwiftData).
/// Le foto non sono nel database: sono file separati gestiti da ImageStore, referenziati per nome.
@Model
final class Garment {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = GarmentCategory.other.rawValue
    var subcategory: String = ""
    var colorName: String = "Nero"
    var secondaryColorName: String = ""
    var hue: Double = 0
    var saturation: Double = 0
    var brightness: Double = 0.1
    var pattern: String = "Tinta unita"
    var seasons: [String] = [Season.allSeasonsTag]
    var material: String = ""
    var brand: String = ""
    var size: String = ""
    var style: String = GarmentStyle.casual.rawValue
    var personalNotes: String = ""
    var photoFileName: String = ""
    var cutoutFileName: String = ""
    var dateAdded: Date = Date()
    var lastWornDate: Date?
    var wearCount: Int = 0

    init(draft d: GarmentDraft) {
        id = d.id
        update(from: d)
    }

    /// Categoria tipizzata (il database salva il testo).
    var category: GarmentCategory {
        get { GarmentCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var color: HSBColor {
        HSBColor(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Copia i campi dalla bozza. L'id non cambia mai.
    func update(from d: GarmentDraft) {
        name = d.name
        category = d.category
        subcategory = d.subcategory
        colorName = d.colorName
        secondaryColorName = d.secondaryColorName
        hue = d.hue
        saturation = d.saturation
        brightness = d.brightness
        pattern = d.pattern
        seasons = d.seasons
        material = d.material
        brand = d.brand
        size = d.size
        style = d.style
        personalNotes = d.personalNotes
        photoFileName = d.photoFileName
        cutoutFileName = d.cutoutFileName
        dateAdded = d.dateAdded
        lastWornDate = d.lastWornDate
        wearCount = d.wearCount
    }
}

extension Garment {
    /// Dopo quanti giorni senza uso un capo viene segnalato come dimenticato.
    static let unusedThresholdDays = 60

    /// true se il capo non viene indossato da più di `unusedThresholdDays`.
    /// Un capo appena aggiunto usa la data di aggiunta come riferimento.
    var isUnused: Bool {
        let reference = lastWornDate ?? dateAdded
        guard let limit = Calendar.current.date(byAdding: .day, value: -Garment.unusedThresholdDays, to: .now) else {
            return false
        }
        return reference < limit
    }
}
