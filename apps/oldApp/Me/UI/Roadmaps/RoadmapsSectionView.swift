import SwiftUI

struct RoadmapsSectionView: View {
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            NavigationStack {
                RoadmapsListView()
            }
        } else {
            NavigationSplitView {
                RoadmapsListView()
            } detail: {
                ContentUnavailableView("Select a roadmap", systemImage: "map")
            }
        }
    }
}

#Preview {
    RoadmapsSectionView()
}
