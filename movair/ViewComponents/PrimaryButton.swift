import SwiftUI

struct PrimaryButton: View {
    enum Style {
        case filled
        case outlined
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
            .overlay {
                if style == .outlined {
                    Capsule()
                        .strokeBorder(Color.Brand.blue700, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(title)
    }

    private var foregroundColor: Color {
        switch style {
        case .filled: return Color.Brand.white
        case .outlined: return Color.Brand.blue900
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .filled: return Color.Brand.blue900
        case .outlined: return Color.white.opacity(0.8)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryButton(title: "Start", systemImage: "location.north.fill") {}
        PrimaryButton(title: "Pause") {}
        PrimaryButton(title: "Finish", style: .outlined) {}
        PrimaryButton(title: "Resume") {}
    }
    .padding()
}
