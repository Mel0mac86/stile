import Foundation

/// Archivio delle foto dei capi: file nella cartella privata dell'app, mai caricati su server.
enum ImageStore {
    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Capi", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for fileName: String) -> URL {
        folder.appendingPathComponent(fileName)
    }

    /// Scrive i dati in un nuovo file e restituisce il nome del file.
    static func write(_ data: Data, ext: String) throws -> String {
        let name = UUID().uuidString + "." + ext
        try data.write(to: url(for: name), options: .atomic)
        return name
    }

    static func data(for fileName: String) -> Data? {
        guard !fileName.isEmpty else { return nil }
        return try? Data(contentsOf: url(for: fileName))
    }

    static func delete(_ fileName: String) {
        guard !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// Elimina tutte le foto (usato da "Cancella tutti i dati").
    static func deleteAll() {
        try? FileManager.default.removeItem(at: folder)
    }
}
