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
    @State private var sampleMessage: String?

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PokéVault")
                        .font(PV.brand(.title))
                        .foregroundStyle(PV.onScreen)
                    Text("Bundle-ID: com.pokevault.collection")
                        .font(PV.monoCaption())
                        .foregroundStyle(PV.onScreenMuted)
                    Text("Version 0.3.4 · Nahfokus-Scanner")
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                }
            }
            .listRowBackground(PV.listRow)

            Section("Sideloadly / App-IDs") {
                Text("Dieselbe Bundle-ID wiederverwendet die App beim Neuinstallieren — es wird typischerweise **keine neue** App-ID verbraucht, wenn du die IPA über die bestehende App installierst.")
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreen)
                Text("Free Apple-IDs haben ein knappes App-ID-Kontingent (~10/Woche). Nicht nach jedem Commit neu sideloaden — warte auf Meilenstein-IPAs.")
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
                Text("Keine zusätzlichen Targets (Watch/Widgets) in diesem Projekt.")
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
            }
            .listRowBackground(PV.listRow)

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
                    .foregroundStyle(PV.onScreen)
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
                    .foregroundStyle(PV.onScreen)
                    Toggle("Beispiel-Hinweise anzeigen", isOn: Binding(
                        get: { settings.showSampleDataBanner },
                        set: {
                            settings.showSampleDataBanner = $0
                            settings.updatedAt = .now
                        }
                    ))
                    .tint(PV.readout)
                    .foregroundStyle(PV.onScreen)
                } else {
                    Text("Einstellungen werden initialisiert…")
                        .foregroundStyle(PV.onScreenMuted)
                        .onAppear {
                            modelContext.insert(AppSettings())
                            try? modelContext.save()
                        }
                }
            }
            .listRowBackground(PV.listRow)

            Section("Beispieldaten") {
                Text("Standard: leerer Store. Kein Auto-Seed beim Start.")
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
                if SampleDataSeeder.hasSampleData(in: modelContext) {
                    Text("Es sind noch Beispieldaten vorhanden (z. B. von einer älteren Version).")
                        .font(PV.caption())
                        .foregroundStyle(PV.secondary)
                    Button("Beispieldaten entfernen", role: .destructive) {
                        let n = SampleDataSeeder.clearSampleData(in: modelContext)
                        sampleMessage = n > 0
                            ? "\(n) Beispiel-Einträge entfernt. Kein erneutes Seeding."
                            : "Keine Beispieldaten gefunden."
                    }
                }
                Button("Beispieldaten laden") {
                    let ok = SampleDataSeeder.loadSampleData(in: modelContext, force: false)
                    sampleMessage = ok
                        ? "Beispieldaten geladen (klar als Beispiel markiert)."
                        : "Sammlung nicht leer — Beispieldaten werden nicht überschrieben."
                }
                .foregroundStyle(PV.readout)
                if let sampleMessage {
                    Text(sampleMessage)
                        .font(PV.caption())
                        .foregroundStyle(PV.statusWarn)
                }
            }
            .listRowBackground(PV.listRow)

            Section("Backup (lokal)") {
                Button("JSON-Export teilen") {
                    exportBackup()
                }
                .foregroundStyle(PV.readout)
                Button("JSON-Import") {
                    showImporter = true
                }
                .foregroundStyle(PV.readout)
                if let importMessage {
                    Text(importMessage)
                        .font(PV.caption())
                        .foregroundStyle(PV.onScreenMuted)
                }
            }
            .listRowBackground(PV.listRow)

            Section("Datenquellen") {
                Text("TCGdex kostenlos, kein API-Schlüssel. Preise nur aus vorhandenen Cardmarket-EUR-Feldern oder manuell. Siehe API_SOURCES.md.")
                    .font(PV.caption())
                    .foregroundStyle(PV.onScreenMuted)
            }
            .listRowBackground(PV.listRow)
        }
        .scrollContentBackground(.hidden)
        .pvScreenBackground()
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    try? modelContext.save()
                    dismiss()
                }
                .foregroundStyle(PV.readout)
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
