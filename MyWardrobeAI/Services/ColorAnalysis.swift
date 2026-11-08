import CoreGraphics

/// Tinta in spazio HSB. Tonalità, saturazione e luminosità vanno da 0 a 1.
struct HSBColor: Hashable {
    var hue: Double
    var saturation: Double
    var brightness: Double
}

/// Colore della palette: nome in italiano e tinta di riferimento.
struct PaletteEntry {
    let name: String
    let color: HSBColor
}

/// Analisi dei colori di un capo (solo CoreGraphics, quindi testabile fuori da UIKit).
enum ColorAnalysis {
    struct Swatch {
        let name: String
        let color: HSBColor
        /// Quota dei pixel del soggetto (0...1).
        let share: Double
    }

    struct Result {
        let primary: Swatch
        let secondary: Swatch?
        /// true se il capo sembra a fantasia: molti colori distinti e nessuno dominante.
        let isPattern: Bool
    }

    /// Palette di riferimento. Serve sia al riconoscimento sia alla scelta manuale nella scheda.
    static let palette: [PaletteEntry] = [
        PaletteEntry(name: "Nero", color: HSBColor(hue: 0, saturation: 0, brightness: 0.1)),
        PaletteEntry(name: "Bianco", color: HSBColor(hue: 0, saturation: 0, brightness: 0.97)),
        PaletteEntry(name: "Grigio", color: HSBColor(hue: 0, saturation: 0, brightness: 0.55)),
        PaletteEntry(name: "Beige", color: HSBColor(hue: 0.1, saturation: 0.2, brightness: 0.85)),
        PaletteEntry(name: "Marrone", color: HSBColor(hue: 0.07, saturation: 0.6, brightness: 0.4)),
        PaletteEntry(name: "Rosso", color: HSBColor(hue: 0.0, saturation: 0.8, brightness: 0.8)),
        PaletteEntry(name: "Arancione", color: HSBColor(hue: 0.07, saturation: 0.8, brightness: 0.95)),
        PaletteEntry(name: "Giallo", color: HSBColor(hue: 0.14, saturation: 0.8, brightness: 0.95)),
        PaletteEntry(name: "Verde", color: HSBColor(hue: 0.33, saturation: 0.6, brightness: 0.6)),
        PaletteEntry(name: "Azzurro", color: HSBColor(hue: 0.48, saturation: 0.45, brightness: 0.9)),
        PaletteEntry(name: "Blu", color: HSBColor(hue: 0.61, saturation: 0.7, brightness: 0.7)),
        PaletteEntry(name: "Blu navy", color: HSBColor(hue: 0.64, saturation: 0.7, brightness: 0.3)),
        PaletteEntry(name: "Viola", color: HSBColor(hue: 0.75, saturation: 0.6, brightness: 0.6)),
        PaletteEntry(name: "Rosa", color: HSBColor(hue: 0.9, saturation: 0.4, brightness: 0.95))
    ]

    static func paletteEntry(named name: String) -> PaletteEntry? {
        palette.first { $0.name == name }
    }

    /// Analizza i colori di un'immagine. Restituisce nil se il soggetto è troppo piccolo o invisibile.
    /// Le zone trasparenti (sfondo già rimosso) vengono ignorate.
    static func analyze(_ image: CGImage) -> Result? {
        // Riduce l'immagine a 48x48 pixel: basta per i colori dominanti ed è veloce.
        let side = 48
        let bytesPerRow = side * 4
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: side * bytesPerRow, alignment: 4)
        defer { buffer.deallocate() }
        guard let context = CGContext(
            data: buffer, width: side, height: side, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: side, height: side))
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        let pixels = buffer.assumingMemoryBound(to: UInt8.self)

        // Raggruppa i colori in secchi di 16 livelli per canale e ne calcola la media.
        var buckets: [Int: (count: Int, r: Int, g: Int, b: Int)] = [:]
        var visible = 0
        for i in 0..<(side * side) {
            let o = i * 4
            guard pixels[o + 3] > 200 else { continue }   // scarta pixel trasparenti o semitrasparenti
            let r = Int(pixels[o]), g = Int(pixels[o + 1]), b = Int(pixels[o + 2])
            let key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
            var entry = buckets[key] ?? (0, 0, 0, 0)
            entry.count += 1
            entry.r += r
            entry.g += g
            entry.b += b
            buckets[key] = entry
            visible += 1
        }
        guard visible >= 40 else { return nil }

        let sorted = buckets.values.sorted { $0.count > $1.count }
        func swatch(_ e: (count: Int, r: Int, g: Int, b: Int)) -> Swatch {
            let n = Double(e.count)
            let hsb = rgbToHSB(Double(e.r) / n / 255, Double(e.g) / n / 255, Double(e.b) / n / 255)
            return Swatch(name: colorName(for: hsb), color: hsb, share: n / Double(visible))
        }

        let primary = swatch(sorted[0])
        // Secondario: il gruppo più presente con un nome diverso dal principale e quota ≥ 6%.
        let secondary = sorted.dropFirst()
            .map(swatch)
            .first { $0.share >= 0.06 && $0.name != primary.name }
        // Fantasia: almeno 4 colori significativi e nessuno dominante.
        let significant = sorted.filter { Double($0.count) / Double(visible) >= 0.06 }.count
        let isPattern = significant >= 4 && primary.share < 0.5

        return Result(primary: primary, secondary: secondary, isPattern: isPattern)
    }

    /// Nome italiano di un colore a partire da HSB.
    static func colorName(for c: HSBColor) -> String {
        let h = c.hue, s = c.saturation, b = c.brightness
        if b < 0.18 { return "Nero" }
        if s < 0.12 { return b > 0.85 ? "Bianco" : "Grigio" }
        if s < 0.3 && b > 0.6 && h < 0.18 { return "Beige" }
        switch h {
        case ..<0.04, 0.95...: return "Rosso"
        case 0.04..<0.11: return b < 0.5 ? "Marrone" : "Arancione"
        case 0.11..<0.18: return "Giallo"
        case 0.18..<0.45: return "Verde"
        case 0.45..<0.52: return "Azzurro"
        case 0.52..<0.70: return b < 0.35 ? "Blu navy" : "Blu"
        case 0.70..<0.82: return "Viola"
        default: return "Rosa"
        }
    }

    /// Conversione RGB → HSB (valori 0...1).
    static func rgbToHSB(_ r: Double, _ g: Double, _ b: Double) -> HSBColor {
        let maxC = max(r, g, b), minC = min(r, g, b), d = maxC - minC
        var h = 0.0
        if d > 0 {
            if maxC == r { h = (g - b) / d }
            else if maxC == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return HSBColor(hue: h, saturation: maxC == 0 ? 0 : d / maxC, brightness: maxC)
    }

    /// Un colore è "neutro" se è nero, bianco o grigio: sta bene con quasi tutto.
    static func isNeutral(_ c: HSBColor) -> Bool {
        c.saturation < 0.15 || c.brightness < 0.18
    }

    /// Armonia tra due colori, da 0 (stonano) a 1 (si abbinano bene).
    /// Regole: neutri con tutto; tinte vicine; complementari e triadi; due colori vivaci opposti stonano.
    static func harmony(_ a: HSBColor, _ b: HSBColor) -> Double {
        if isNeutral(a) || isNeutral(b) { return 0.9 }
        var d = abs(a.hue - b.hue)
        if d > 0.5 { d = 1 - d }   // distanza sul cerchio dei colori
        if d < 0.09 { return 0.85 }
        if d > 0.42 && d < 0.58 { return 0.8 }
        if d > 0.25 && d < 0.35 { return 0.7 }
        if a.saturation > 0.5 && b.saturation > 0.5 { return 0.3 }
        return 0.55
    }
}
