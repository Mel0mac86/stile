import Foundation

/// Slot dell'outfit: ogni categoria di capo appartiene a uno slot.
/// L'ordine dei casi è anche l'ordine di disposizione nella composizione grafica.
enum OutfitSlot: Int, CaseIterable {
    case top, dress, bottom, shoes, outerwear, accessory
}

/// Categorie di capi richieste dalla specifica (testo italiano mostrato all'utente).
enum GarmentCategory: String, CaseIterable, Identifiable, Codable {
    case tshirt = "Magliette"
    case shirt = "Camicie"
    case polo = "Polo"
    case sweatshirt = "Felpe"
    case knitwear = "Maglioni"
    case jacket = "Giacche"
    case coat = "Cappotti"
    case trousers = "Pantaloni"
    case jeans = "Jeans"
    case shorts = "Pantaloncini"
    case dress = "Abiti"
    case skirt = "Gonne"
    case shoes = "Scarpe"
    case sneakers = "Sneakers"
    case boots = "Stivali"
    case accessory = "Accessori"
    case bag = "Borse"
    case belt = "Cinture"
    case other = "Altro"

    var id: String { rawValue }
    var title: String { rawValue }

    /// Slot dell'outfit a cui appartiene la categoria.
    var slot: OutfitSlot {
        switch self {
        case .tshirt, .shirt, .polo, .sweatshirt, .knitwear: return .top
        case .dress: return .dress
        case .trousers, .jeans, .shorts, .skirt: return .bottom
        case .shoes, .sneakers, .boots: return .shoes
        case .jacket, .coat: return .outerwear
        case .accessory, .bag, .belt, .other: return .accessory
        }
    }

    /// Calore del capo: 1 = leggerissimo, 5 = molto caldo.
    var warmth: Int {
        switch self {
        case .tshirt, .shorts, .skirt, .accessory, .bag, .belt: return 1
        case .shirt, .polo, .trousers, .jeans, .dress, .shoes, .sneakers, .other: return 2
        case .sweatshirt, .jacket: return 3
        case .knitwear, .boots: return 4
        case .coat: return 5
        }
    }

    /// Eleganza tipica del capo (1 informale ... 5 formale), usata se lo stile non è indicato.
    var defaultFormality: Int {
        switch self {
        case .tshirt, .sweatshirt, .jeans, .shorts, .sneakers: return 1
        case .polo, .knitwear, .boots, .accessory, .bag, .belt, .other: return 2
        case .shirt, .jacket, .trousers, .dress, .skirt, .shoes: return 3
        case .coat: return 4
        }
    }

    /// Icona SF Symbols per le liste. Solo simboli presenti da iOS 16/17.
    var symbolName: String {
        switch self {
        case .tshirt, .shirt, .polo, .sweatshirt, .knitwear, .jacket, .coat, .dress: return "tshirt"
        case .bag: return "bag"
        case .accessory, .belt: return "sparkles"
        case .shoes, .sneakers, .boots: return "shoeprints.fill"
        case .trousers, .jeans, .shorts, .skirt, .other: return "hanger"
        }
    }
}

/// Stagioni selezionabili. Un capo può anche valere per "Tutte le stagioni".
enum Season: String, CaseIterable, Identifiable, Codable {
    case spring = "Primavera"
    case summer = "Estate"
    case autumn = "Autunno"
    case winter = "Inverno"

    /// Etichetta per i capi adatti a ogni stagione.
    static let allSeasonsTag = "Tutte le stagioni"

    var id: String { rawValue }

    /// Stagione di una data (calendario dell'emisfero nord).
    static func of(_ date: Date) -> Season {
        switch Calendar.current.component(.month, from: date) {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    /// Stagione di oggi.
    static var current: Season { of(Date()) }

    /// Calore richiesto quando non c'è una temperatura reale (1...5).
    var warmth: Int {
        switch self {
        case .summer: return 1
        case .spring: return 2
        case .autumn: return 3
        case .winter: return 4
        }
    }
}

/// Stili di un capo. Il livello di eleganza serve al motore per abbinare capi coerenti.
enum GarmentStyle: String, CaseIterable, Identifiable {
    case sporty = "Sportivo"
    case casual = "Casual"
    case smartCasual = "Smart casual"
    case elegant = "Elegante"
    case formal = "Formale"

    var id: String { rawValue }

    /// Livello di eleganza: 1 = molto informale, 5 = formale.
    var formality: Int {
        switch self {
        case .sporty: return 1
        case .casual: return 2
        case .smartCasual: return 3
        case .elegant: return 4
        case .formal: return 5
        }
    }
}
