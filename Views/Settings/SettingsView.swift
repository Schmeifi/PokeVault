import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Query private var owned: [OwnedCard]
    @Query private var wishlist: [WishlistEntry]
    @Query private var catalog: [CardCatalogEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var importMessage: String?
    @State private var showImporter = false

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PokéVault")
                        .font(PV.brand(.title))
                    Text("Bundle-ID: com.pokevault.collection")
                        .font(PV.monoCaption())
                    Text("Version 0.3.0 · Meilenstein Phases 2–7")
                        .font(PV.caption())
                }
            }

            Section("Sideloadly / App-IDs") {
                Text("Dieselbe Bundle-ID wiederverwendet die App beim Neuinstallieren — es wird typischerweise **keine neue** App-ID verbraucht, wenn du die IPA über die bestehende App installierst.")
                    .font(.footnote)
                Text("Free Apple-IDs haben ein knappes App-ID-Kontingent (~10/Woche). Nicht nach jedem Commit neu sideloaden — warte auf Meilenstein-IPAs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Keine zusätzlichen Targets (Watch/Widgets) in diesem Projekt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Voreinstellungen") {
                if let settings {
                    Picker("Bevorzugte Sprache", selection: Binding(
                        get: { settings.preferredLanguage },
                        set: {
                            settings.preferredLanguage = $0
                            settings.updatedAt = .now
                        }
                    )) {
                        ForEach(CardLanguage.allCases) { language in
                            Text(language.displayNameDE).tag(language)
                        }
                    }
                    Picker("Standard-Zustand", selection: Binding(
                        get: { settings.defaultCondition },
                        set: {
                            settings.defaultCondition = $0
                            settings.updatedAt = .now
                        }
                    )) {
                        ForEach(CardCondition.allCases) { condition in
                            Text(condition.displayNameDE).tag(condition)
                        }
                    }
                    Toggle("Beispiel-Hinweise anzeigen", isOn: Binding(
                        get: { settings.showSampleDataBanner },
                        set: {
                            settings.showSampleDataBanner = $0
                            settings.updatedAt = .now
                        }
                    ))
                } else {
                    Text("Einstellungen werden initialisiert…")
                        .onAppear {
                            modelContext.insert(AppSettings())
                            try? modelContext.save()
                        }
                }
            }

            Section("Backup (lokal)") {
                Button("JSON-Export teilen") {
                    exportBackup()
                }
                Button("JSON-Import") {
                    showImporter = true
                }
                if let importMessage {
                    Text(importMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Datenquellen") {
                Text("TCGdex kostenlos, kein API-Schlüssel. Preise nur aus vorhandenen Cardmarket-EUR-Feldern oder manuell.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    let data = try Data(contentsOf: url)
                    let count = try BackupService.importJSON(data, into: modelContext)
                    importMessage = "\(count) Exemplare importiert."
                } catch {
                    importMessage = error.localizedDescription
                }
            case .failure(let error):
                importMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showExporter) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    private func exportBackup() {
        let payload = BackupService.makePayload(owned: owned, wishlist: wishlist, catalog: catalog)
        do {
            exportURL = try BackupService.writeExportBundle(payload: payload, owned: owned)
            showExporter = true
        } catch {
            importMessage = error.localizedDescription
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(ModelContainerFactory.previewContainer())
}
