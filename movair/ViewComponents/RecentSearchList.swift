import SwiftUI

struct RecentSearchList: View {
    let recents: [RecentSearch]
    var onSelect: (RecentSearch) -> Void
    var onDelete: (RecentSearch) -> Void

    var body: some View {
        if !recents.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(recents.enumerated()), id: \.element.id) { index, recent in
                    row(for: recent)

                    if index < recents.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func row(for recent: RecentSearch) -> some View {
        Button {
            onSelect(recent)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .foregroundStyle(Color.Brand.darkgray)
                    .frame(width: 20)

                Text(recent.title)
                    .font(Font.Brand.body)
                    .foregroundStyle(Color.primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                onDelete(recent)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.Brand.primaryRed)

                    Text("Delete")
                        .foregroundStyle(Color.Brand.primaryRed)
                }
            }
            .tint(.clear)
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete(recent)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    RecentSearchList(
        recents: [
            RecentSearch(title: "AEON Mall BSD City"),
            RecentSearch(title: "The Breeze")
        ],
        onSelect: { _ in },
        onDelete: { _ in }
    )
    .padding()
}
