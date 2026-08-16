import SwiftUI

struct MapNavigationBanner: View {
    let distanceKm: Double
    let instruction: String
    let pageCount: Int
    let currentPage: Int
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onBack?()
            } label: {
                Image(systemName: "arrow.turn.up.left")
                    .font(Font.Brand.largeTitle)
                    .foregroundStyle(Color.Brand.labelPrimary)
                    .frame(width: 72, height: 72)
                    .background(Color.Brand.labelPrimary.opacity(0.2), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.0f km", distanceKm))
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(Color.primary)

                Text(instruction)
                    .font(Font.Brand.title2)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                if pageCount > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.Brand.labelPrimary : Color.Brand.labelPrimary.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 10)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
    }
}

#Preview {
    MapNavigationBanner(
        distanceKm: 3,
        instruction: "Turn left onto Jalan Damai Foresta",
        pageCount: 3,
        currentPage: 0
    )
    .padding()
}
