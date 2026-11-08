import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Profilo: preferenze, strumenti, backup, eliminazione dei dati e privacy.
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(AppSettings.appearanceKey) private var appearance = AppearanceMode.system.rawValue
    @AppStorage(AppSettings.preferredStyleKey) private var preferredStyle = ""
    @AppStorage(AppSettings.weatherConsentKey) private var weatherConsent = false

    @State private var showExporter = false
    @State private var exportDocument = BackupDocument()
    @State private var showImporter = false
    @State private var confirmDelete = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Aspetto") {
                    Picker("Tema", selection: $appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                }

                Section {
                    Picker("Stile preferito", selection: $preferredStyle) {
                        Text("Nessuna preferenza").tag("")
                        ForEach(GarmentStyle.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                } header: {
                    Text("Preferenze")
                } footer: {
                    Text("L'app impara anche da come valuti gli outfit: più li valuti, più i suggerimenti ti somigliano.")
                }

                Section("Strumenti") {
                    NavigationLink {
                        PackingView()
                    } label: {
                        Label("Valigia automatica", systemImage: "suitcase")
                    }
                    NavigationLink {
                        UnusedGarmentsView()
                    } label: {
                        Label("Capi dimenticati", systemImage: "clock.arrow.circlepath")
                    }
                }

                Section {
                    Toggle("Meteo con la mia posizione", isOn: $weatherConsent)
                } footer: {
                    Text("Se attivo, l'app chiede la posizione solo per leggere il meteo. Non la salva e non la condivide.")
                }

                Section {
                    Button("Esporta backup") { exportBackup() }
                    Button("Importa backup") { showImporter = true }
                    Button("Cancella tutti i dati", role: .destructive) { confirmDelete = true }
                } header: {
                    Text("Dati")
                } footer: {
                    Text("Il backup è un file JSON con capi, foto, outfit e calendario. Salvalo in iCloud Drive per non perdere nulla.")
                }

                Section("Privacy") {
                    Text("Le foto dei capi restano nella memoria di questo iPhone. Non serve un account e nessuna foto viene caricata su server esterni.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profilo")
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "MyWardrobeAI-backup"
            ) { result in
                if case .failure(let error) = result {
                    message = "Esportazione non riuscita: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .confirmationDialog("Cancellare tutti i dati?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Cancella tutto", role: .destructive) { deleteAll() }
            } message: {
                Text("Capi, foto, outfit e calendario verranno eliminati. Non si può annullare: esporta prima un backup.")
            }
            .alert("MyWardrobe AI", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func exportBackup() {
        do {
            exportDocument = BackupDocument(data: try BackupService.makeBackup(context: context))
            showExporter = true
        } catch {
            message = "Esportazione non riuscita: \(error.localizedDescription)"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let restored = try BackupService.restore(data, context: context)
            message = "Importati \(restored.garments) capi e \(restored.outfits) outfit."
        } catch {
            message = "Importazione non riuscita: \(error.localizedDescription)"
        }
    }

    private func deleteAll() {
        do {
            try BackupService.deleteEverything(context: context)
            message = "Tutti i dati sono stati cancellati."
        } catch {
            message = "Cancellazione non riuscita: \(error.localizedDescription)"
        }
    }
}

/// Capi non indossati da molto tempo: vale la pena rimetterli in gioco o regalarli.
struct UnusedGarmentsView: View {
    @Query(sort: \Garment.dateAdded) private var garments: [Garment]

    var body: some View {
        let unused = garments.filter(\.isUnused)
        List {
            if unused.isEmpty {
                Text("Ottimo: tutti i tuoi capi sono stati indossati di recente.")
                    .foregroundStyle(.secondary)
            }
            ForEach(unused) { garment in
                HStack(spacing: 12) {
                    GarmentImage(cutout: garment.cutoutFileName, photo: garment.photoFileName)
                        .frame(width: 50, height: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(garment.name).font(.subheadline.weight(.semibold))
                        Text(lastWornText(garment))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Capi dimenticati")
    }

    private func lastWornText(_ garment: Garment) -> String {
        guard let date = garment.lastWornDate else { return "Mai indossato" }
        return "Ultimo utilizzo: \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}
