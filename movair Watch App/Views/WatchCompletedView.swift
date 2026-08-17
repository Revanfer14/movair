import SwiftUI

struct WatchCompletedView: View {
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Brand.gray.opacity(0.35))
                .frame(width: 72, height: 72)

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
