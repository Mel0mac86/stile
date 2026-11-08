import Foundation

/// Occasioni scelte dall'utente. Ognuna ha un livello di eleganza atteso (1 informale ... 5 formale).
enum Occasion: String, CaseIterable, Identifiable {
    case work = "Lavoro"
    case office = "Ufficio"
    case importantMeeting = "Riunione importante"
    case jobInterview = "Colloquio di lavoro"
    case friends = "Uscita con amici"
    case romantic = "Appuntamento romantico"
    case elegantDinner = "Cena elegante"
    case wedding = "Matrimonio"
    case ceremony = "Cerimonia"
    case party = "Festa"
    case aperitif = "Aperitivo"
    case leisure = "Tempo libero"
    case sport = "Sport"
    case holiday = "Vacanza"
    case trip = "Viaggio"
    case walk = "Passeggiata"
    case special = "Evento particolare"

    var id: String { rawValue }

    var formality: Int {
        switch self {
        case .leisure, .sport, .walk: return 1
        case .aperitif, .friends, .holiday, .trip: return 2
        case .work, .romantic, .party, .special: return 3
        case .office, .importantMeeting, .jobInterview, .elegantDinner: return 4
        case .wedding, .ceremony: return 5
        }
    }

    var symbolName: String {
        switch self {
        case .work: return "briefcase"
        case .office: return "building.2"
        case .importantMeeting: return "person.2"
        case .jobInterview: return "doc.text"
        case .friends: return "person.3"
        case .romantic: return "heart"
        case .elegantDinner: return "fork.knife"
        case .wedding: return "sparkles"
        case .ceremony: return "star"
        case .party: return "party.popper"
        case .aperitif: return "wineglass"
        case .leisure: return "house"
        case .sport: return "figure.run"
        case .holiday: return "sun.max"
        case .trip: return "airplane"
        case .walk: return "figure.walk"
        case .special: return "calendar"
        }
    }

    /// Riconosce l'occasione da una descrizione libera (es. "festa in terrazza").
    /// Le regole più specifiche sono prima. Restituisce nil se nessuna parola corrisponde.
    static func inferred(from text: String) -> Occasion? {
        let t = text.lowercased()
        let rules: [(keywords: [String], occasion: Occasion)] = [
            (["colloquio", "interview"], .jobInterview),
            (["matrimonio", "nozze", "sposa", "sposo"], .wedding),
            (["cerimonia", "laurea", "battesimo"], .ceremony),
            (["riunione", "meeting", "presentazione"], .importantMeeting),
            (["ufficio"], .office),
            (["lavoro"], .work),
            (["cena"], .elegantDinner),
            (["appuntamento", "romantic"], .romantic),
            (["aperitivo", "drink"], .aperitif),
            (["festa", "party", "compleanno"], .party),
            (["amici"], .friends),
            (["sport", "palestra", "corsa", "running", "allenamento"], .sport),
            (["vacanza", "spiaggia", "holiday"], .holiday),
            (["viaggio", "aereo", "treno", "trip"], .trip),
            (["passeggiata", "parco"], .walk),
            (["tempo libero", "relax", "weekend"], .leisure),
            (["evento"], .special)
        ]
        return rules.first { rule in rule.keywords.contains { t.contains($0) } }?.occasion
    }
}
