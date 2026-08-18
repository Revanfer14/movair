import SwiftUI

struct WatchCircularIconButton: View {
    let systemImage: String
    let label: String
    var tint: Color = Color.Brand.blue600
    var foreground: Color = Color.Brand.white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(foreground)
                    .frame(width: 52, height: 52)
                    .background(tint, in: Circle())

                Text(label)
                    .font(Font.Brand.watchCaption)
                    .foregroundStyle(Color.Brand.darkgray)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    HStack(spacing: 24) {
        WatchCircularIconButton(systemImage: "play.fill", label: "Resume", tint: Color.Brand.blue600) {}
        WatchCircularIconButton(systemImage: "flag.checkered", label: "Finish", tint: Color.Brand.primaryYellow, foreground: Color.black) {}
    }
    .padding()
}
