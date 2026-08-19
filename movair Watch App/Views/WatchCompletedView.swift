import SwiftUI

struct WatchCompletedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fireworks")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Color.Brand.primaryYellow)

            VStack(spacing: 6) {
                Text("Activity complete!")
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.primary)

                Text("Check the summary on\nyour phone")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }
}

#Preview {
    WatchCompletedView()
}
