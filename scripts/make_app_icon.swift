// Genera l'icona 1024×1024 dell'app (senza trasparenza, come richiede App Store).
// Uso: swift scripts/make_app_icon.swift <percorso-output.png>
import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let size = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let colorSpace = CGColorSpaceCreateDeviceRGB()

// noneSkipLast: nessun canale alfa nel file finale.
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Impossibile creare il contesto grafico")
}

// Sfondo: sfumatura calda, come la palette neutra dell'app.
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [CGColor(red: 0.96, green: 0.94, blue: 0.91, alpha: 1),
                                   CGColor(red: 0.86, green: 0.82, blue: 0.75, alpha: 1)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])

// Appendino stilizzata in nero antracite: gancio, asta e spalle.
ctx.setStrokeColor(CGColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1))
ctx.setLineWidth(40)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// Disegno centrato verticalmente: gancio in alto, spalle simmetriche, barra in basso.
// Gancio (cerchio): centro (512, 690), raggio 52.
ctx.strokeEllipse(in: CGRect(x: 512 - 52, y: 690 - 52, width: 104, height: 104))
// Asta verticale: dal fondo del gancio fino al punto di snodo delle spalle.
ctx.move(to: CGPoint(x: 512, y: 638))
ctx.addLine(to: CGPoint(x: 512, y: 440))
ctx.strokePath()
// Spalle simmetriche
ctx.move(to: CGPoint(x: 512, y: 440))
ctx.addLine(to: CGPoint(x: 230, y: 280))
ctx.move(to: CGPoint(x: 512, y: 440))
ctx.addLine(to: CGPoint(x: 794, y: 280))
// Barra inferiore
ctx.move(to: CGPoint(x: 230, y: 280))
ctx.addLine(to: CGPoint(x: 794, y: 280))
ctx.strokePath()

guard let image = ctx.makeImage() else { fatalError("Impossibile creare l'immagine") }
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Impossibile creare il file PNG")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Salvataggio PNG non riuscito") }
print("Icona scritta in \(outPath)")
