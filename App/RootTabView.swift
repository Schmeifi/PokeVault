import SwiftUI
import SwiftData

struct RootTabView: View {
    @State private var showSettings = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            CardGalleryView()
                .tabItem {
                    Label("Meine Karten", systemImage: "rectangle.stack.fill")
                }

            CollectionsListView()
                .tabItem {
                    Label("Sammlungen", systemImage: "folder.fill")
                }

            ScannerPlaceholderView()
                .tabItem {
                    Label("Scanner", systemImage: "camera.viewfinder")
                }

            DiscoverView()
                .tabItem {
                    Label("Entdecken", systemImage: "magnifyingglass")
                }
        }
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

#Preview {
    RootTabView()
        .modelContainer(ModelContainerFactory.previewContainer())
}
