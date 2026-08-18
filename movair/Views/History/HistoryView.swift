import SwiftUI
import MapKit

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedTripForDetail: TripSummary?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                header
                mainCard
                    .padding(.horizontal, 16)
                    .offset(y: -24)

                ridesSection

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
        .sheet(item: $selectedTripForDetail) { trip in
            TripSummaryView(trip: trip) {
                selectedTripForDetail = nil
            }
        }
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

    @ViewBuilder
    private var ridesSection: some View {
        if viewModel.selectedDayTrips.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "bicycle")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.Brand.darkgray.opacity(0.6))
                Text("No rides on this day")
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.Brand.darkgray)
                Text("Completed rides will appear here")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(viewModel.selectedDayTrips.count == 1 ? "Your Ride" : "Your Rides (\(viewModel.selectedDayTrips.count))")
                        .font(Font.Brand.title2Bold)
                        .foregroundStyle(Color.Brand.labelPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ForEach(viewModel.selectedDayTrips) { trip in
                    recentTripCard(trip)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func recentTripCard(_ trip: TripSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MapViewComponent(
                recenterTrigger: .constant(false),
                centerCoordinate: trip.displayCoordinates.first,
                showsUserLocation: false,
                routeCoordinates: trip.displayCoordinates,
                originCoordinate: trip.displayCoordinates.first,
                destinationCoordinate: trip.displayCoordinates.last,
                fitsRouteInView: true,
                routeEdgePadding: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18),
                showsOriginMarker: true,
                isInteractionEnabled: false
            )
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .allowsHitTesting(false)

            HStack(alignment: .top) {
                Text(trip.routeTitle)
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                Spacer()

                Menu {
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.deleteTrip(trip)
                        }
                    } label: {
                        Label("Delete Ride", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(Font.Brand.footnote)
                        .foregroundStyle(Color.Brand.primaryRed.opacity(0.85))
                        .padding(6)
                        .background(Color.Brand.secondaryRed, in: Circle())
                }
                .tint(Color.Brand.primaryRed)
                .accessibilityLabel("Delete ride")
            }

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
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTripForDetail = trip
        }
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.deleteTrip(trip)
                }
            } label: {
                Label("Delete Ride", systemImage: "trash")
            }
        }
        .tint(Color.Brand.primaryRed)
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
