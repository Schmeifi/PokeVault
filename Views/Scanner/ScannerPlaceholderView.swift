import SwiftUI

/// Phase-1-Platzhalter: Vision/AVFoundation-Scanner folgt in späteren Phasen.
/// Keine kostenpflichtige Cloud-Bilderkennung.
struct ScannerPlaceholderView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Scanner")
                    .font(.title2.weight(.semibold))
                Text("Die Kamerascans mit Vision Framework kommen in einer späteren Phase. Phase 1 speichert Scan-Ergebnisse lokal vor und nutzt keine kostenpflichtige KI.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Lokal auf dem Gerät", systemImage: "iphone")
                    Label("Keine Cloud-KI-Kosten", systemImage: "eurosign.circle")
                    Label("Manuelles Hinzufügen ist verfügbar", systemImage: "plus.rectangle.on.rectangle")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Scanner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    ScannerPlaceholderView()
}
