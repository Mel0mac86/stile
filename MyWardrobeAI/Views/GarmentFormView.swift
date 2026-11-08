import SwiftUI

/// Scheda modificabile del capo: usata per i nuovi capi e per le modifiche.
struct GarmentFormView: View {
    @Binding var draft: GarmentDraft
    let title: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var seasonTags: [String] {
        Season.allCases.map(\.rawValue) + [Season.allSeasonsTag]
    }

    var body: some View {
        Form {
            if let data = draft.previewData(), let image = UIImage(data: data) {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                }
            }
            Section("Dati principali") {
                TextField("Nome", text: $draft.name)
                Picker("Categoria", selection: $draft.category) {
                    ForEach(GarmentCategory.allCases) { Text($0.title).tag($0) }
                }
                TextField("Sottocategoria (es. oxford, chino)", text: $draft.subcategory)
                Picker("Colore principale", selection: $draft.colorName) {
                    ForEach(ColorAnalysis.palette, id: \.name) { Text($0.name).tag($0.name) }
                }
                Picker("Colore secondario", selection: $draft.secondaryColorName) {
                    Text("Nessuno").tag("")
                    ForEach(ColorAnalysis.palette, id: \.name) { Text($0.name).tag($0.name) }
                }
                Picker("Motivo", selection: $draft.pattern) {
                    Text("Tinta unita").tag("Tinta unita")
                    Text("Fantasia").tag("Fantasia")
                }
            }
            Section("Stagione") {
                ForEach(seasonTags, id: \.self) { tag in
                    Toggle(tag, isOn: seasonBinding(tag))
                }
            }
            Section("Dettagli") {
                TextField("Materiale (es. cotone, impermeabile)", text: $draft.material)
                TextField("Marca (facoltativa)", text: $draft.brand)
                TextField("Taglia (facoltativa)", text: $draft.size)
                Picker("Stile", selection: $draft.style) {
                    ForEach(GarmentStyle.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
            }
            Section("Note personali") {
                TextField("Note", text: $draft.personalNotes, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva", action: onSave)
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onChange(of: draft.colorName) { _, newValue in
            // Scegliere un colore a mano aggiorna anche la tinta usata per gli abbinamenti.
            if let entry = ColorAnalysis.paletteEntry(named: newValue) {
                draft.hue = entry.color.hue
                draft.saturation = entry.color.saturation
                draft.brightness = entry.color.brightness
            }
        }
    }

    /// Collegamento di una stagione al suo interruttore. "Tutte le stagioni" è esclusiva.
    private func seasonBinding(_ tag: String) -> Binding<Bool> {
        Binding(
            get: { draft.seasons.contains(tag) },
            set: { isOn in
                var list = draft.seasons
                if tag == Season.allSeasonsTag {
                    list = isOn ? [tag] : []
                } else {
                    list.removeAll { $0 == Season.allSeasonsTag }
                    if isOn {
                        if !list.contains(tag) { list.append(tag) }
                    } else {
                        list.removeAll { $0 == tag }
                    }
                }
                draft.seasons = list
            }
        )
    }
}
