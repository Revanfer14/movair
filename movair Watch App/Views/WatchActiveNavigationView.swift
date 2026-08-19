import SwiftUI

struct WatchActiveNavigationView: View {
    @ObservedObject var viewModel: WatchNavigationViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)

            Text(formattedDistance)
                .font(Font.Brand.watchMetric)
                .foregroundStyle(Color.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Spacer().frame(height: 8)

            HStack(spacing: 16) {
                Text("\(viewModel.accumulatedExposureUg) µg")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)

                Text(viewModel.elapsedTimeLabel)
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
            }

            Spacer(minLength: 12)

            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var controls: some View {
        switch viewModel.state {
        case .active:
            WatchPrimaryButton(
                title: "Pause",
                tint: Color.Brand.primaryYellow,
                foreground: Color.black
            ) {
                viewModel.pause()
            }

        case .paused:
            HStack(spacing: 24) {
                WatchCircularIconButton(
                    systemImage: "play.fill",
                    label: "Resume",
                    tint: Color.Brand.blue600
                ) {
                    viewModel.resume()
                }

                WatchCircularIconButton(
                    systemImage: "flag.checkered",
                    label: "Finish",
                    tint: Color.Brand.primaryYellow,
                    foreground: Color.black
                ) {
                    viewModel.finish()
                }
            }

        default:
            EmptyView()
        }
    }

    private var formattedDistance: String {
        let meters = viewModel.distanceKm * 1000
        if meters < 1000 {
            let rounded = max(0, Int((meters / 10).rounded()) * 10)
            return "\(rounded) m"
        }
        if viewModel.distanceKm < 10 {
            return String(format: "%.1f km", viewModel.distanceKm)
        }
        return String(format: "%.0f km", viewModel.distanceKm)
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
            }()
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
            }()
        )
    }
}
