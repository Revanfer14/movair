import SwiftUI

struct MapDestinationArrivalSheet: View {
    let destinationTitle: String
    let distanceKm: Double
    let durationMinutes: Int
    let averageSpeedKmh: Double
    let accumulatedExposureUg: Int
    let exposureLevel: ExposureLevel
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.Brand.blue900.opacity(0.2))
                        .frame(width: 64, height: 64)

                    Image(systemName: "flag.checkered")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.Brand.blue900)
                }

                Text("You've Arrived!")
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(Color.primary)

                Text("Reached \(destinationTitle)")
                    .font(Font.Brand.body)
                    .foregroundStyle(Color.Brand.darkgray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                statCard(
                    title: "Exposure",
                    value: "\(accumulatedExposureUg) µg",
                    badge: exposureLevel
                )
                statCard(
                    title: "Distance",
                    value: distanceLabel,
                    badge: nil
                )
                statCard(
                    title: "Duration",
                    value: "\(durationMinutes) min",
                    badge: nil
                )
            }
            .padding(.horizontal, 16)

            PrimaryButton(
                title: "View Trip Summary",
                systemImage: nil,
                action: onConfirm
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var distanceLabel: String {
        if distanceKm == floor(distanceKm) {
            return String(format: "%.0f km", distanceKm)
        }
        return String(format: "%.1f km", distanceKm)
    }

    private func statCard(title: String, value: String, badge: ExposureLevel?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.Brand.darkgray)

            Text(value)
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.primary)

            if let badge {
                ExposureBadge(level: badge, showsAqi: false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    MapDestinationArrivalSheet(
        destinationTitle: "fX Sudirman",
        distanceKm: 14.5,
        durationMinutes: 38,
        averageSpeedKmh: 12,
        accumulatedExposureUg: 85,
        exposureLevel: .moderate,
        onConfirm: {}
    )
}
