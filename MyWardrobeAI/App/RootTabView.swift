import SwiftUI

/// Menu inferiore con le cinque sezioni richieste: Home, Guardaroba, Stilista AI, Preferiti, Profilo.
struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            WardrobeView()
                .tabItem { Label("Guardaroba", systemImage: "hanger") }
            StylistView()
                .tabItem { Label("Stilista AI", systemImage: "sparkles") }
            FavoritesView()
                .tabItem { Label("Preferiti", systemImage: "heart") }
            ProfileView()
                .tabItem { Label("Profilo", systemImage: "person.crop.circle") }
        }
    }
}
