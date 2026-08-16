import SwiftUI

struct MapRoundTripToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bicycle")
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.primary)

            Text("Round Trip")
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.primary)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.Brand.blue900)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        .accessibilityLabel("Round Trip")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

#Preview {
    MapRoundTripToggle(isOn: .constant(true))
}
