import SwiftUI

struct NavigationInstructionBanner: View {
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
                    .foregroundStyle(Color.Brand.blue900)
                    .frame(width: 72, height: 72)
                    .background(Color.Brand.blue900.opacity(0.2), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.0f km", distanceKm))
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.primary)

                Text(instruction)
                    .font(Font.Brand.body)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                if pageCount > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.Brand.blue600 : Color.Brand.gray)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .padding(.top, 2)
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
    NavigationInstructionBanner(
        distanceKm: 3,
        instruction: "Turn left onto Jalan Damai Foresta",
        pageCount: 3,
        currentPage: 0
    )
    .padding()
}
