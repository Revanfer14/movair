import SwiftUI

struct SearchResultList: View {
    let results: [SearchResult]
    var onSelect: (SearchResult) -> Void

    var body: some View {
        if !results.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    row(for: result)

                    if index < results.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func row(for result: SearchResult) -> some View {
        Button {
            onSelect(result)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.Brand.darkgray)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(Font.Brand.body)
                        .foregroundStyle(Color.primary)
                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(Font.Brand.footnote)
                            .foregroundStyle(Color.Brand.darkgray)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchResultList(
        results: [
            SearchResult(title: "The Breeze", subtitle: "BSD City, Tangerang"),
            SearchResult(title: "The Breeze XXI", subtitle: "Cinema")
        ],
        onSelect: { _ in }
    )
    .padding()
}
