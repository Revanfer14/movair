import SwiftUI

struct WatchActiveNavigationView: View {
    @ObservedObject var viewModel: WatchNavigationViewModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)

            // Primary metric: distance traveled
            Text(formattedDistance)
                .font(Font.Brand.watchMetric)
                .foregroundStyle(Color.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Spacer().frame(height: 8)

            // Secondary metrics: exposure + elapsed time
            HStack(spacing: 16) {
                Text("\(viewModel.accumulatedExposureUg) µg")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)

                Text(formattedElapsed)
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
            }

            Text(formattedHeartRate)
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.Brand.darkgray)
                .padding(.top, 6)

            Spacer(minLength: 12)

            // Native controls
            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
            }
        }
    }

    // Controls
    @ViewBuilder
    private var controls: some View {
        switch viewModel.state {
        case .active:
            Button("Pause") {
                viewModel.pause()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Brand.blue900)

        case .paused:
            HStack(spacing: 12) {
                Button {
                    viewModel.finish()
                } label: {
                    Text("Finish")
                }
                .buttonStyle(.bordered)
                .foregroundStyle(Color.Brand.primaryRed)

                Button {
                    viewModel.resume()
                } label: {
                    Text("Resume")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.Brand.blue900)
            }

        default:
            EmptyView()
        }
    }

    // Formatting
    private var formattedDistance: String {
        if viewModel.distanceKm < 10 {
            String(format: "%.1f km", viewModel.distanceKm)
        } else {
            String(format: "%.0f km", viewModel.distanceKm)
        }
    }

    private var formattedElapsed: String {
        "\(viewModel.elapsedMinutes) min"
    }

    private var formattedHeartRate: String {
        guard let heartRateBPM = viewModel.heartRateBPM else {
            return "-- bpm"
        }
        return "\(Int(heartRateBPM.rounded())) bpm"
    }
}

#Preview("Active") {
    NavigationStack {
        WatchActiveNavigationView(
            viewModel: {
                let vm = WatchNavigationViewModel()
                vm.distanceKm = 0.5
                vm.accumulatedExposureUg = 10
                vm.elapsedMinutes = 1
                vm.state = .active
                return vm
            }(),
            onDismiss: {}
        )
    }
}

#Preview("Paused") {
    NavigationStack {
        WatchActiveNavigationView(
            viewModel: {
                let vm = WatchNavigationViewModel()
                vm.distanceKm = 0.5
                vm.accumulatedExposureUg = 10
                vm.elapsedMinutes = 1
                vm.state = .paused
                return vm
            }(),
            onDismiss: {}
        )
    }
}
