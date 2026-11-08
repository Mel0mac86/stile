import SwiftUI
import SwiftData

/// Punto di ingresso. Il database SwiftData è locale: nessun account né server.
@main
struct MyWardrobeAIApp: App {
    @AppStorage(AppSettings.appearanceKey) private var appearance = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(AppearanceMode(rawValue: appearance)?.colorScheme)
                .tint(.primary)
        }
        .modelContainer(for: [Garment.self, SavedOutfit.self, WearEntry.self])
    }
}
