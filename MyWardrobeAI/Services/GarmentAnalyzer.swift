import Foundation
import CoreGraphics
import CoreImage
import Vision

/// Risultato dell'analisi automatica di una foto di capo.
struct GarmentAnalysis {
    /// Capo ritagliato senza sfondo (nil se Vision non trova un soggetto).
    let cutout: CGImage?
    /// Categoria suggerita. Va sempre confermata dall'utente nella scheda.
    let category: GarmentCategory
    /// Etichetta grezza riconosciuta da Vision, usata come sottocategoria suggerita.
    let subcategory: String
    let colors: ColorAnalysis.Result?
}

/// Pipeline di riconoscimento: rimozione sfondo → classificazione → colori.
/// Usa solo framework Apple (Vision, Core Image): nessun modello esterno né connessione.
enum GarmentAnalyzer {
    private static let ciContext = CIContext()

    /// Analisi sincrona: chiamarla fuori dal thread principale (vedi AddGarmentView).
    static func analyze(_ image: CGImage) -> GarmentAnalysis {
        let cutout = removeBackground(from: image)
        let subject = cutout ?? image
        let (category, label) = classify(subject)
        let colors = ColorAnalysis.analyze(subject)
        return GarmentAnalysis(cutout: cutout, category: category, subcategory: label, colors: colors)
    }

    /// Ritaglia il soggetto principale usando la maschera di primo piano di Vision (iOS 17+).
    /// Restituisce nil se non trova nulla: in quel caso si usa la foto intera.
    static func removeBackground(from image: CGImage) -> CGImage? {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            let ciImage = CIImage(cvPixelBuffer: buffer)
            return ciContext.createCGImage(ciImage, from: ciImage.extent)
        } catch {
            return nil
        }
    }

    /// Classifica l'immagine con Vision e prende la prima etichetta riconosciuta come capo.
    static func classify(_ image: CGImage) -> (GarmentCategory, String) {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return (.other, "")
        }
        // Le etichette arrivano in ordine di confidenza.
        let observations = (request.results ?? []).filter { $0.confidence > 0.05 }
        for observation in observations {
            if let category = category(for: observation.identifier) {
                return (category, observation.identifier.replacingOccurrences(of: "_", with: " "))
            }
        }
        return (.other, "")
    }

    /// Traduce un'etichetta Vision (in inglese) in una categoria dell'app.
    /// L'ordine conta: "t-shirt" deve essere valutata prima di "shirt".
    static func category(for label: String) -> GarmentCategory? {
        let s = label.lowercased()
        let rules: [(String, GarmentCategory)] = [
            ("jean", .jeans), ("denim", .jeans),
            ("short", .shorts),
            ("sneaker", .sneakers), ("boot", .boots),
            ("sandal", .shoes), ("shoe", .shoes), ("footwear", .shoes), ("heel", .shoes),
            ("handbag", .bag), ("purse", .bag), ("backpack", .bag), ("bag", .bag),
            ("belt", .belt),
            ("skirt", .skirt), ("dress", .dress), ("gown", .dress),
            ("coat", .coat), ("parka", .coat),
            ("jacket", .jacket), ("blazer", .jacket), ("vest", .jacket),
            ("hoodie", .sweatshirt), ("sweatshirt", .sweatshirt),
            ("sweater", .knitwear), ("cardigan", .knitwear), ("knit", .knitwear),
            ("polo", .polo),
            ("t-shirt", .tshirt), ("tshirt", .tshirt), ("tee", .tshirt),
            ("shirt", .shirt), ("blouse", .shirt),
            ("pant", .trousers), ("trouser", .trousers), ("legging", .trousers),
            ("watch", .accessory), ("scarf", .accessory), ("glasses", .accessory),
            ("jewel", .accessory), ("necklace", .accessory)
        ]
        return rules.first { s.contains($0.0) }?.1
    }
}
