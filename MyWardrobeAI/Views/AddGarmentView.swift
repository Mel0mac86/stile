import SwiftUI
import SwiftData
import PhotosUI

/// Aggiunta di un capo: foto (fotocamera o galleria) → analisi automatica → scheda da confermare.
struct AddGarmentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isAnalyzing = false
    @State private var draft = GarmentDraft()
    @State private var hasDraft = false
    @State private var errorMessage: String?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isAnalyzing {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Analizzo il capo…").foregroundStyle(.secondary)
                    }
                } else if hasDraft {
                    GarmentFormView(draft: $draft, title: "Nuovo capo") { save() }
                } else {
                    sourceChooser
                }
            }
            .navigationTitle("Aggiungi capo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    Task { await analyze(image) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await analyze(image)
                    } else {
                        errorMessage = "Non sono riuscito a leggere la foto selezionata."
                    }
                }
            }
            .alert("Attenzione", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var sourceChooser: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Fotografa il capo su un piano chiaro, senza altri vestiti intorno. L'app ne ritaglia la forma e propone tipo e colori: puoi correggere tutto.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button {
                showCamera = true
            } label: {
                Label("Scatta foto", systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!cameraAvailable)
            if !cameraAvailable {
                Text("Fotocamera non disponibile su questo dispositivo: usa la galleria.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Scegli dalla galleria", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Spacer()
        }
        .padding()
    }

    /// Analizza la foto in background e precompila la scheda con i suggerimenti.
    @MainActor
    private func analyze(_ image: UIImage) async {
        isAnalyzing = true
        let upright = image.resizedUpright()
        let analysis: GarmentAnalysis? = await Task.detached(priority: .userInitiated) { () -> GarmentAnalysis? in
            guard let cg = upright.cgImage else { return nil }
            return GarmentAnalyzer.analyze(cg)
        }.value

        var d = GarmentDraft()
        d.pendingPhoto = upright.jpegData(compressionQuality: 0.85)
        if let a = analysis {
            d.category = a.category
            d.subcategory = a.subcategory.capitalized
            if let colors = a.colors {
                d.colorName = colors.primary.name
                d.hue = colors.primary.color.hue
                d.saturation = colors.primary.color.saturation
                d.brightness = colors.primary.color.brightness
                d.pattern = colors.isPattern ? "Fantasia" : "Tinta unita"
                d.secondaryColorName = colors.secondary?.name ?? ""
            }
            d.pendingCutout = a.cutout.flatMap { UIImage(cgImage: $0).pngData() }
            // Stile suggerito dalla categoria (1 = sportivo ... 5 = formale).
            d.style = GarmentStyle.allCases[d.category.defaultFormality - 1].rawValue
        } else {
            errorMessage = "Analisi non riuscita: compila la scheda a mano."
        }
        d.name = d.category == .other ? "Nuovo capo" : "\(d.category.title) \(d.colorName.lowercased())"
        draft = d
        hasDraft = true
        isAnalyzing = false
    }

    private func save() {
        do {
            try GarmentStore.save(draft, existing: nil, context: context)
            dismiss()
        } catch {
            errorMessage = "Salvataggio non riuscito: \(error.localizedDescription)"
        }
    }
}
