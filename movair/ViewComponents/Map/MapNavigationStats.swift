import SwiftUI

struct MapNavigationStats: View {
    let mode: NavigationMode
    let distanceKm: Double
    let durationMinutes: Int
    let averageSpeedKmh: Double
    let accumulatedExposureUg: Int
    let exposureLevel: ExposureLevel
    let isOffRoute: Bool
    let unattributedDurationMinutes: Int
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    var onFinish: (() -> Void)?

    init(
        mode: NavigationMode,
        distanceKm: Double,
        durationMinutes: Int,
        averageSpeedKmh: Double,
        accumulatedExposureUg: Int,
        exposureLevel: ExposureLevel,
        isOffRoute: Bool = false,
        unattributedDurationMinutes: Int = 0,
        onPause: (() -> Void)? = nil,
        onResume: (() -> Void)? = nil,
        onFinish: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.distanceKm = distanceKm
        self.durationMinutes = durationMinutes
        self.averageSpeedKmh = averageSpeedKmh
        self.accumulatedExposureUg = accumulatedExposureUg
        self.exposureLevel = exposureLevel
        self.isOffRoute = isOffRoute
        self.unattributedDurationMinutes = unattributedDurationMinutes
        self.onPause = onPause
        self.onResume = onResume
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Measured Exposure")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)

                HStack(spacing: 8) {
                    ExposureBadge(level: exposureLevel, showsAqi: true, badgeSize: "big")

                    Circle()
                        .fill(Color.Brand.darkgray.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .padding(.horizontal, 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(accumulatedExposureUg) µg")
                            .font(Font.Brand.title2Bold)
                            .foregroundStyle(Color.primary)

                        Text("Accumulated")
                            .font(Font.Brand.footnote)
                            .foregroundStyle(Color.Brand.darkgray)
                    }
                }

                if isOffRoute {
                    Text("Off route")
                        .font(Font.Brand.footnote)
                        .foregroundStyle(Color.Brand.primaryOrange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack(spacing: 0) {
                metric(value: String(format: "%.0f km", distanceKm), label: "Distance")
                    .frame(maxWidth: .infinity)

                Spacer()
                Divider()
                    .frame(height: 54)
                Spacer()

                metric(value: "\(durationMinutes) min", label: "Time")
                    .frame(maxWidth: .infinity)

                Spacer()
                Divider()
                    .frame(height: 54)
                Spacer()

                metric(value: String(format: "%.0f km/h", averageSpeedKmh), label: "Avg speed")
                    .frame(maxWidth: .infinity)
            }

            if mode == .active {
                PrimaryButton(title: "Pause", action: { onPause?() })
            } else {
                HStack(spacing: 12) {
                    PrimaryButton(title: "Finish", style: .unfilled, action: { onFinish?() })
                    PrimaryButton(title: "Resume", action: { onResume?() })
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 14, x: 0, y: 6)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
            Text(label)
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.Brand.darkgray)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.35).ignoresSafeArea()
        VStack(spacing: 20) {
            MapNavigationStats(
                mode: .active,
                distanceKm: 14,
                durationMinutes: 37,
                averageSpeedKmh: 8,
                accumulatedExposureUg: 115,
                exposureLevel: .low
            )
            MapNavigationStats(
                mode: .paused,
                distanceKm: 14,
                durationMinutes: 37,
                averageSpeedKmh: 8,
                accumulatedExposureUg: 115,
                exposureLevel: .veryHigh
            )
        }
        .padding()
    }
}
