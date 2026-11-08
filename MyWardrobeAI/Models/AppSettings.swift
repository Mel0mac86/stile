import SwiftUI

/// Chiavi delle preferenze salvate in UserDefaults (@AppStorage).
enum AppSettings {
    static let appearanceKey = "appearance"
    static let weatherConsentKey = "weatherConsent"
    static let preferredStyleKey = "preferredStyle"
    static let manualTempEnabledKey = "manualTempEnabled"
    static let manualTempKey = "manualTemp"
}

/// Tema dell'app: segue il sistema oppure forzato chiaro/scuro.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "Sistema"
    case light = "Chiaro"
    case dark = "Scuro"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
