import SwiftUI

struct WatchPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = Color.Brand.blue900
    var foreground: Color = Color.Brand.white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(Font.Brand.bodyBold)
                }
                Text(title)
                    .font(Font.Brand.bodyBold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(foreground)
            .background(tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    WatchPrimaryButton(title: "Pause") {}
        .padding()
}
