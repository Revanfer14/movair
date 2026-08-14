import SwiftUI

struct NavigationStatsPanel: View {
    enum Mode {
        case active
        case paused
    }

    let mode: Mode
    let distanceKm: Double
    let durationMinutes: Int
    let averageSpeedKmh: Double
    let accumulatedExposureUg: Int
    let exposureLevel: ExposureLevel
    var onPause: (() -> Void)? = nil
    var onResume: (() -> Void)? = nil
    var onFinish: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            if mode == .active {
                activeContent
            } else {
                pausedContent
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 14, x: 0, y: 6)
    }

    private var activeContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Estimated Exposure")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)

                HStack(spacing: 8) {
                    ExposureBadge(level: exposureLevel)
                    Text("\(accumulatedExposureUg) µg")
                        .font(Font.Brand.title2Bold)
                        .foregroundStyle(Color.primary)
                    Text("Accumulated")
                        .font(Font.Brand.footnote)
                        .foregroundStyle(Color.Brand.darkgray)
                    Spacer(minLength: 0)
                }
            }

            HStack {
                metric(value: String(format: "%.0f km", distanceKm), label: "Distance")
                
                Spacer()
                Divider()
                    .frame(height: 54)
                    .foregroundStyle(Color.Brand.darkgray)
                Spacer()
                
                metric(value: "\(durationMinutes) min", label: "Time")
                
                Spacer()
                Divider()
                    .frame(height: 54)
                    .foregroundStyle(Color.Brand.darkgray)
                Spacer()
                
                metric(value: String(format: "%.0f km/h", averageSpeedKmh), label: "Avg speed")
            }

            PrimaryButton(title: "Pause", action: { onPause?() })
        }
    }

    private var pausedContent: some View {
        VStack(spacing: 16) {
            HStack {
                metric(value: "\(durationMinutes) min", label: "Time")
                
                Spacer()
                Divider()
                    .frame(height: 54)
                    .foregroundStyle(Color.Brand.darkgray)
                Spacer()
                
                metric(value: String(format: "%.0f km", distanceKm), label: "Distance")
                
                Spacer()
                Divider()
                    .frame(height: 54)
                    .foregroundStyle(Color.Brand.darkgray)
                Spacer()
                
                VStack(spacing: 4) {
                    ExposureBadge(level: exposureLevel)
                    Text("Exposure")
                        .font(Font.Brand.footnote)
                        .foregroundStyle(Color.Brand.darkgray)
                }
            }

            HStack(spacing: 12) {
                PrimaryButton(title: "Finish", style: .outlined, action: { onFinish?() })
                PrimaryButton(title: "Resume", action: { onResume?() })
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.primary)
            Text(label)
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.Brand.darkgray)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NavigationStatsPanel(
            mode: .active,
            distanceKm: 14,
            durationMinutes: 37,
            averageSpeedKmh: 8,
            accumulatedExposureUg: 115,
            exposureLevel: .low
        )
        NavigationStatsPanel(
            mode: .paused,
            distanceKm: 14,
            durationMinutes: 37,
            averageSpeedKmh: 8,
            accumulatedExposureUg: 115,
            exposureLevel: .low
        )
    }
    .padding()
}
