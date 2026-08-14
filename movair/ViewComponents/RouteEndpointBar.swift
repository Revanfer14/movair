import SwiftUI

struct RouteEndpointBar: View {
    let originTitle: String
    let destinationTitle: String
    var onSwap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                endpointRow(
                    icon: "location.circle.fill",
                    iconColor: Color.Brand.blue600,
                    title: originTitle
                )

                Divider()
                    .padding(.vertical, 12)

                endpointRow(
                    icon: "mappin.and.ellipse",
                    iconColor: Color.Brand.blue600,
                    title: destinationTitle
                )
            }

            Button {
                onSwap?()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(Font.Brand.footnoteBold)
                    .foregroundStyle(Color.Brand.darkgray)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Swap origin and destination")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private func endpointRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 18)
            Text(title)
                .font(Font.Brand.body)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    RouteEndpointBar(
        originTitle: "Current location",
        destinationTitle: "BXChange Mall"
    )
    .padding()
}
