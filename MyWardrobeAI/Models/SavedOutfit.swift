import Foundation
import SwiftData

/// Outfit salvato (preferito, valutato o indossato). Conserva gli ID dei capi:
/// se un capo viene eliminato, l'outfit mostra solo i capi che restano.
@Model
final class SavedOutfit {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var occasionRaw: String = Occasion.leisure.rawValue
    var itemIDs: [String] = []
    /// Valutazione da 1 a 5; 0 = non valutato.
    var rating: Int = 0
    var isFavorite: Bool = false
    var reasons: [String] = []
    var createdAt: Date = Date()

    init(id: UUID = UUID(), title: String, occasion: Occasion, itemIDs: [UUID], reasons: [String],
         isFavorite: Bool, rating: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.occasionRaw = occasion.rawValue
        self.itemIDs = itemIDs.map(\.uuidString)
        self.reasons = reasons
        self.isFavorite = isFavorite
        self.rating = rating
        self.createdAt = createdAt
    }

    var occasion: Occasion { Occasion(rawValue: occasionRaw) ?? .leisure }

    var itemUUIDs: [UUID] { itemIDs.compactMap { UUID(uuidString: $0) } }
}

/// Giorno in cui l'utente ha indossato un outfit (calendario).
@Model
final class WearEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var itemIDs: [String] = []

    init(id: UUID = UUID(), title: String, itemIDs: [UUID], date: Date = .now) {
        self.id = id
        self.title = title
        self.itemIDs = itemIDs.map(\.uuidString)
        self.date = date
    }

    var itemUUIDs: [UUID] { itemIDs.compactMap { UUID(uuidString: $0) } }
}
