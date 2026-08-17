import SwiftUI

struct MapRouteEndpointBar: View {
    let originTitle: String
    let destinationTitle: String
    var onEditOrigin: (() -> Void)? = nil
    var onEditDestination: (() -> Void)? = nil
    var onSwap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    onEditOrigin?()
                } label: {
                    endpointRow(
                        icon: "location.circle.fill",
                        iconColor: Color.Brand.blue600,
                        title: originTitle
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit origin")
                .accessibilityValue(originTitle)

                Divider()
                    .padding(.vertical, 12)

                Button {
                    onEditDestination?()
                } label: {
                    endpointRow(
                        icon: "mappin.and.ellipse",
                        iconColor: Color.Brand.blue600,
                        title: destinationTitle
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit destination")
                .accessibilityValue(destinationTitle)
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
        .contentShape(Rectangle())
    }
}

#Preview {
    MapRouteEndpointBar(
        originTitle: "Current location",
        destinationTitle: "BXChange Mall",
        onEditOrigin: {},
        onEditDestination: {},
        onSwap: {}
    )
    .padding()
}
