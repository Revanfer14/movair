import SwiftUI

struct AppTabView: View {
    enum Tab: Hashable {
        case map
        case history
    }
 
    @State private var selectedTab: Tab = .map
 
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(Tab.map)
 
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(Tab.history)
        }
        .tint(Color.Brand.blue700)
    }
}

#Preview {
    AppTabView()
}
