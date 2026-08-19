import SwiftUI

struct HistoryHighlightCard: View {
    let systemImage: String
    let text: AttributedString

    init(systemImage: String, text: String) {
        self.systemImage = systemImage
        self.text = AttributedString(text)
    }

    init(systemImage: String, attributedText: AttributedString) {
        self.systemImage = systemImage
        self.text = attributedText
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.Brand.labelPrimary)
                .frame(width: 24)

            Text(text)
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 8) {
        HistoryHighlightCard(
            systemImage: "chart.bar.fill",
            text: "Your estimated exposure was 18% lower this week than last week"
        )
        HistoryHighlightCard(
            systemImage: "sun.max.fill",
            text: "Morning rides had ~32% lower estimated exposure than your evening rides"
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
