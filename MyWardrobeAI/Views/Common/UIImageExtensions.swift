import UIKit

extension UIImage {
    /// Ridimensiona e raddrizza la foto. Le foto della fotocamera hanno l'orientamento in metadati EXIF:
    /// ridisegnarle le rende "dritte" e riduce il peso (lato massimo 1600 px).
    func resizedUpright(maxSide: CGFloat = 1600) -> UIImage {
        let ratio = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
