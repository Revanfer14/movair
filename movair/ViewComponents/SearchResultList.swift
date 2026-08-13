import SwiftUI

struct SearchResultList: View {
    let title: String
    let subtitle: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.Brand.darkgray)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.Brand.body)
                        .foregroundStyle(Color.primary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Font.Brand.footnote)
                            .foregroundStyle(Color.Brand.darkgray)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    List {
        SearchResultList(title: "The Breeze", subtitle: "BSD City, Tangerang", onTap: {})
        SearchResultList(title: "The Breeze XXI", subtitle: "Cinema", onTap: {})
    }
}
