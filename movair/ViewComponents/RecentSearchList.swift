import SwiftUI

struct RecentSearchList: View {
    let title: String
    var onTap: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .foregroundStyle(Color.Brand.darkgray)
                    .frame(width: 20)

                Text(title)
                    .font(Font.Brand.body)
                    .foregroundStyle(Color.primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(Color.Brand.danger)
        }
    }
}

#Preview {
    List {
        RecentSearchList(title: "AEON Mall BSD City", onTap: {}, onDelete: {})
        RecentSearchList(title: "The Breeze", onTap: {}, onDelete: {})
    }
}
