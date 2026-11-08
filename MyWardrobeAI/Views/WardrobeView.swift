import SwiftUI
import SwiftData

/// Guardaroba: tutti i capi fotografati, filtrabili per categoria.
struct WardrobeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Garment.dateAdded, order: .reverse) private var garments: [Garment]
    @State private var filter: GarmentCategory?
    @State private var showAdd = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var filtered: [Garment] {
        guard let filter else { return garments }
        return garments.filter { $0.category == filter }
    }

    var body: some View {
        NavigationStack {
            Group {
                if garments.isEmpty {
                    ContentUnavailableView {
                        Label("Il guardaroba è vuoto", systemImage: "hanger")
                    } description: {
                        Text("Fotografa il primo capo per iniziare.")
                    } actions: {
                        Button("Aggiungi un capo") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filtered) { garment in
                                NavigationLink {
                                    GarmentEditView(garment: garment)
                                } label: {
                                    GarmentCard(garment: garment)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        delete(garment)
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Guardaroba")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Aggiungi capo")
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button("Tutti") { filter = nil }
                        ForEach(GarmentCategory.allCases) { category in
                            Button(category.title) { filter = category }
                        }
                    } label: {
                        Label("Filtra", systemImage: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddGarmentView()
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

    private func delete(_ garment: Garment) {
        do {
            try GarmentStore.delete(garment, context: context)
        } catch {
            errorMessage = "Eliminazione non riuscita: \(error.localizedDescription)"
        }
    }
}

/// Scheda di un capo nella griglia.
struct GarmentCard: View {
    let garment: Garment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GarmentImage(cutout: garment.cutoutFileName, photo: garment.photoFileName)
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(garment.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(garment.category.title) · \(garment.colorName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if garment.isUnused {
                Label("Non indossato da tempo", systemImage: "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

/// Modifica di un capo già salvato.
struct GarmentEditView: View {
    let garment: Garment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GarmentDraft
    @State private var errorMessage: String?
    @State private var confirmDelete = false

    init(garment: Garment) {
        self.garment = garment
        _draft = State(initialValue: GarmentDraft(garment: garment))
    }

    var body: some View {
        GarmentFormView(draft: $draft, title: "Scheda capo") {
            save()
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Elimina capo", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Eliminare questo capo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                do {
                    try GarmentStore.delete(garment, context: context)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } message: {
            Text("Il capo e la sua foto verranno eliminati. Gli outfit salvati restano ma senza questo capo.")
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

    private func save() {
        do {
            try GarmentStore.save(draft, existing: garment, context: context)
            dismiss()
        } catch {
            errorMessage = "Salvataggio non riuscito: \(error.localizedDescription)"
        }
    }
}
