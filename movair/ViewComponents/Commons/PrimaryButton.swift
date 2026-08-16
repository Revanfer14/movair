import SwiftUI

struct PrimaryButton: View {
    enum Style {
        case filled
        case unfilled
    }

    let title: String
    var systemImage: String? = nil
    var style: Style = .filled
    var isEnabled: Bool = true
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
            .padding(.vertical, 14)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(title)
    }

    private var foregroundColor: Color {
        switch style {
        case .filled: return Color.Brand.white
        case .unfilled: return Color.Brand.labelPrimary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .filled: return Color.Brand.blue900
        case .unfilled: return Color(.secondarySystemGroupedBackground)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryButton(title: "Start", systemImage: "location.north.fill") {}
        PrimaryButton(title: "Pause") {}
        PrimaryButton(title: "Finish", style: .unfilled) {}
        PrimaryButton(title: "Resume") {}
    }
    .padding()
}
