import Foundation

/// Bozza modificabile di una scheda capo.
/// È usata da creazione, modifica, analisi automatica e ripristino del backup.
struct GarmentDraft {
    var id = UUID()
    var name = ""
    var category: GarmentCategory = .other
    var subcategory = ""
    var colorName = "Nero"
    /// Stringa vuota = nessun colore secondario.
    var secondaryColorName = ""
    var hue = 0.0
    var saturation = 0.0
    var brightness = 0.1
    var pattern = "Tinta unita"
    var seasons: [String] = [Season.allSeasonsTag]
    var material = ""
    var brand = ""
    var size = ""
    var style = GarmentStyle.casual.rawValue
    var personalNotes = ""
    var dateAdded = Date()
    var lastWornDate: Date?
    var wearCount = 0

    /// Nomi dei file già salvati (vuoti per un capo nuovo).
    var photoFileName = ""
    var cutoutFileName = ""
    /// Dati immagine ancora da scrivere su disco (nuovo capo o ripristino backup).
    var pendingPhoto: Data?
    var pendingCutout: Data?

    init() {}

    init(garment g: Garment) {
        id = g.id
        name = g.name
        category = g.category
        subcategory = g.subcategory
        colorName = g.colorName
        secondaryColorName = g.secondaryColorName
        hue = g.hue
        saturation = g.saturation
        brightness = g.brightness
        pattern = g.pattern
        seasons = g.seasons
        material = g.material
        brand = g.brand
        size = g.size
        style = g.style
        personalNotes = g.personalNotes
        dateAdded = g.dateAdded
        lastWornDate = g.lastWornDate
        wearCount = g.wearCount
        photoFileName = g.photoFileName
        cutoutFileName = g.cutoutFileName
    }

    /// Immagine da mostrare nell'anteprima: ritaglio se c'è, altrimenti foto.
    func previewData() -> Data? {
        pendingCutout
            ?? ImageStore.data(for: cutoutFileName)
            ?? pendingPhoto
            ?? ImageStore.data(for: photoFileName)
    }
}
