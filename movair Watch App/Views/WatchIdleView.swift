import SwiftUI

struct WatchIdleView: View {
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Brand.gray.opacity(0.35))
                .frame(width: 72, height: 72)

            Text("Setup your ride\non Your iPhone!")
                .font(Font.Brand.body)
                .foregroundStyle(Color.Brand.darkgray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }
}

#Preview {
    WatchIdleView()
}
