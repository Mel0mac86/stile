import UIKit

/// Cache delle immagini caricate dal disco, per scorrere il guardaroba senza rileggere i file.
enum ImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        let key = fileName as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: ImageStore.url(for: fileName).path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
