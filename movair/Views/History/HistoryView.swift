import SwiftUI
import MapKit

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var recenterTrigger = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                header
                mainCard
                    .padding(.horizontal, 16)
                    .offset(y: -24)

                if let trip = viewModel.latestTrip {
                    recentTripCard(trip)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                highlightsSection
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                aboutSection
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            viewModel.rebuildWeek(around: Date())
        }
        .onReceive(viewModel.store.$trips) { _ in
            viewModel.rebuildWeek(around: viewModel.selectedDate)
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.Brand.blue900

            Image("HistoryHeaderBanner")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .padding(.trailing, -20)
                .padding(.bottom, 28)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your")
                    .font(Font.Brand.title2)
                    .foregroundStyle(Color.Brand.white)
                Text("Estimated")
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(Color.Brand.white)
                Text("Pollution Exposure")
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(Color.Brand.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
    }

    private var mainCard: some View {
        VStack(spacing: 16) {
            HistoryWeekDayPicker(
                weekDates: viewModel.weekDates,
                exposures: viewModel.weekExposures,
                selectedDate: $viewModel.selectedDate
            )

            Divider()

            VStack(spacing: 4) {
                Text(viewModel.selectedDayLevel.title)
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(viewModel.selectedDayLevel.primaryColor)
                Text("Estimated exposure")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
            }

            HistoryExposureGauge(
                percent: viewModel.dailyBudgetPercent,
                lineWidth: 28,
                size: 150,
                showsPercentLabel: false
            )

            VStack(spacing: 2) {
                Text(viewModel.dailyBudgetLabel)
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(Color.primary)
                Text(viewModel.dailyBudgetSubLabel)
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
            }

            budgetUsedText
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    private var budgetUsedText: some View {
        HStack(spacing: 0) {
            Text("\(viewModel.dailyBudgetPercent)%")
                .font(Font.Brand.footnoteBold)
                .foregroundStyle(viewModel.selectedDayLevel.primaryColor)
            Text(" of daily exposure budget used")
                .font(Font.Brand.footnoteBold)
                .foregroundStyle(Color.Brand.darkgray)
        }
    }

    private func recentTripCard(_ trip: TripSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MapViewComponent(
                recenterTrigger: $recenterTrigger,
                centerCoordinate: trip.coordinates.first,
                showsUserLocation: false,
                routeCoordinates: trip.coordinates,
                destinationCoordinate: trip.coordinates.last,
                fitsRouteInView: true
            )
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(trip.routeTitle)
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.primary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(trip.durationLabel)
                Text("·")
                Text(trip.distanceLabel)
                Text("·")
                Image(systemName: "wind")
                Text("\(trip.exposureUg) µg")
            }
            .font(Font.Brand.footnoteBold)
            .foregroundStyle(Color.Brand.labelPrimary)

            Text(trip.relativeDateLabel)
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.Brand.darkgray.opacity(0.85))
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlights")
                .font(Font.Brand.title2Bold)
                .foregroundStyle(Color.Brand.labelPrimary)

            ForEach(viewModel.highlights) { item in
                HistoryHighlightCard(systemImage: item.systemImage, text: item.text)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About Movair")
                .font(Font.Brand.title2Bold)
                .foregroundStyle(Color.Brand.labelPrimary)

            Text("Pollution exposure is the estimated amount of PM₂.₅ you encounter while riding. Your estimate considers air quality, traffic, road conditions, greenery, weather, and the time of your ride. These factors can change throughout your journey, so your actual exposure may be different from the estimate.")
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.Brand.darkgray)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HistoryView()
}
