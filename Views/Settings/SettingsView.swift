import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Environment(\.modelContext) private var modelContext

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Version", value: "0.1.0 (Phase 1)")
                LabeledContent("Bundle-ID", value: "com.pokevault.collection")
                LabeledContent("Ziel", value: "iOS 17+")
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
                        .foregroundStyle(.secondary)
                        .onAppear {
                            modelContext.insert(AppSettings())
                            try? modelContext.save()
                        }
                }
            }

            Section("Datenquellen") {
                Text("Kartendaten: TCGdex (kostenlos, kein API-Schlüssel)")
                Text("Preise: TCGdex Cardmarket-Referenz, manuelle Werte, gespeicherte Stände")
                Text("Keine kostenpflichtigen APIs, kein Scraping.")
                    .foregroundStyle(.secondary)
            }

            Section("Hinweis") {
                Text("PokéVault speichert alles lokal auf dem Gerät (SwiftData). Es ist kein Login und kein Cloud-Backend erforderlich.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(ModelContainerFactory.previewContainer())
}
