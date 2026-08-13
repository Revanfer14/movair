import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Trips Yet",
                systemImage: "clock",
                description: Text("Your route history will appear here.")
            )
            .tint(Color.Brand.blue600)
            .navigationTitle("History")
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    HistoryView()
}
