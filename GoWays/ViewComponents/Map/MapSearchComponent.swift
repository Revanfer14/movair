import SwiftUI

struct MapSearchComponent: View {

    var placeholder: String = "Search"
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)
                
                Text(placeholder)
                    .font(Font.Brand.body)
                    .foregroundStyle(.secondary)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(placeholder))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens search")
    }
}

#Preview {
    MapSearchComponent(placeholder: "Search for routes", onTap: {})
        .padding()
}
