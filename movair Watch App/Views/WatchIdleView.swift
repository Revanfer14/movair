import SwiftUI

struct WatchIdleView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.Brand.blue600)
                    .frame(width: 72, height: 72)

                Image(systemName: "bicycle")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.Brand.white)
            }

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
