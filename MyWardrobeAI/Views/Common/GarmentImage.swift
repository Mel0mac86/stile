import SwiftUI

/// Mostra il ritaglio del capo (senza sfondo) o, se manca, la foto originale.
struct GarmentImage: View {
    let cutout: String
    let photo: String

    var body: some View {
        if let image = ImageCache.image(cutout) ?? ImageCache.image(photo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            Image(systemName: "photo")
                .font(.title)
                .foregroundStyle(.secondary)
        }
    }
}
