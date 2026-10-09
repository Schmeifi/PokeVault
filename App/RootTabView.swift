import SwiftUI
import SwiftData

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "circle.grid.cross.fill")
                }

            CardGalleryView()
                .tabItem {
                    Label("Meine Karten", systemImage: "rectangle.stack.fill")
                }

            CollectionsListView()
                .tabItem {
                    Label("Sammlungen", systemImage: "folder.fill")
                }

            NavigationStack {
                CardScannerView()
            }
            .tabItem {
                Label("Scanner", systemImage: "camera.viewfinder")
            }

            DiscoverView()
                .tabItem {
                    Label("Entdecken", systemImage: "magnifyingglass")
                }
        }
        .tint(PV.readout)
    }
}

#Preview {
    RootTabView()
        .modelContainer(ModelContainerFactory.previewContainer())
}
