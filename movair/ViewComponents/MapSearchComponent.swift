import SwiftUI

struct MapSearchComponent: View {
    @Binding var text: String
    
    var placeholder: String = "Search"
    var isFocused: FocusState<Bool>.Binding
    var showsCloseButton: Bool = false
    var isInteractive: Bool = true
    var onMicTap: (() -> Void)?
    var onClose: (() -> Void)?
    var onBarTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            fieldContent
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onTapGesture {
                    guard !isInteractive else { return }
                    onBarTap?()
                }
                .accessibilityElement(children: isInteractive ? .contain : .ignore)
                .accessibilityLabel(isInteractive ? "" : placeholder)
                .accessibilityAddTraits(isInteractive ? [] : .isButton)
                .accessibilityHint(isInteractive ? "" : "Opens search")

            if showsCloseButton {
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.Brand.darkgray)
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close search")
            }
        }
    }

    @ViewBuilder
    private var fieldContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.Brand.darkgray)

            if isInteractive {
                TextField(placeholder, text: $text)
                    .font(Font.Brand.body)
                    .foregroundStyle(Color.primary)
                    .focused(isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
            } else {
                Text(placeholder)
                    .font(Font.Brand.body)
                    .foregroundStyle(Color.Brand.darkgray)
                Spacer(minLength: 0)
            }

            if isInteractive, !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.Brand.darkgray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search text")
            } else if isInteractive {
                Button {
                    onMicTap?()
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(Color.Brand.darkgray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search by voice")
            } else {
                Image(systemName: "mic.fill")
                    .foregroundStyle(Color.Brand.darkgray)
            }
        }
    }
}

#Preview("Interactive") {
    struct PreviewWrapper: View {
        @State var text = ""
        @FocusState var focused: Bool
        var body: some View {
            MapSearchComponent(text: $text, placeholder: "Search for routes", isFocused: $focused, showsCloseButton: true)
                .padding()
        }
    }
    return PreviewWrapper()
}

#Preview("Display-only entry point") {
    struct PreviewWrapper: View {
        @State var text = ""
        @FocusState var focused: Bool
        var body: some View {
            MapSearchComponent(
                text: $text,
                placeholder: "Search for routes",
                isFocused: $focused,
                isInteractive: false,
                onBarTap: {}
            )
            .padding()
        }
    }
    return PreviewWrapper()
}
