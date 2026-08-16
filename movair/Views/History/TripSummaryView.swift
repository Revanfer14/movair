import SwiftUI
import MapKit

struct TripSummaryView: View {
    let trip: TripSummary
    var onDismiss: () -> Void

    @State private var recenterTrigger = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    headerSection
                    rideCard
                        .padding(.horizontal, 16)
                    Color.clear.frame(height: 88)
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                PrimaryButton(title: "Got it", action: onDismiss)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
        }
        .toolbar(.hidden, for: .tabBar)
    }

   private var headerSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Trip Summary")
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(Color.Brand.white)

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(Font.Brand.footnote)
                    Text(trip.dateLabel)
                        .font(Font.Brand.footnote)
                }
                .foregroundStyle(Color.Brand.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 72)
            .padding(.bottom, 24)

            exposureCard
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.Brand.blue900)
            .ignoresSafeArea(edges: .top)
        )
    }

    private var exposureCard: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ExposureBadge(level: trip.exposureLevel, showsAqi: true)

                Text("\(trip.exposureUg) µg")
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(exposureValueColor)

                Text("Your Estimated Exposure")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)

            Rectangle()
                .fill(Color.Brand.gray.opacity(0.4))
                .frame(width: 1)
                .padding(.vertical, 2)

            VStack(spacing: 6) {
                HistoryExposureGauge(
                    percent: trip.dailyExposurePercent,
                    lineWidth: 12,
                    size: 120
                )

                Text("of your daily exposure\nused on this ride")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 12)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var exposureValueColor: Color {
        switch trip.exposureLevel {
        case .low: return Color.Brand.primaryGreen
        case .moderate: return Color.Brand.primaryYellow
        case .high: return Color.Brand.primaryOrange
        case .veryHigh: return Color.Brand.primaryRed
        case .extreme: return Color.Brand.primaryMaroon
        }
    }

    private var rideCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "bicycle")
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.Brand.labelPrimary)
                Text("Your Ride")
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.Brand.labelPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            MapViewComponent(
                recenterTrigger: $recenterTrigger,
                centerCoordinate: trip.coordinates.first,
                showsUserLocation: false,
                routeCoordinates: trip.coordinates,
                destinationCoordinate: trip.coordinates.last,
                fitsRouteInView: true
            )
            .frame(height: 224)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Text(trip.routeTitle)
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)

                MapRouteMetricRow(items: [
                    RouteMetric(value: trip.distanceLabel, label: "Distance"),
                    RouteMetric(value: trip.durationLabel, label: "Duration"),
                    RouteMetric(value: trip.speedLabel, label: "Avg. speed")
                ])
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    TripSummaryView(
        trip: TripSummary(
            originTitle: "Green Office Park",
            destinationTitle: "BXChange Mall",
            distanceKm: 10.5,
            durationMinutes: 100,
            averageSpeedKmh: 10,
            exposureUg: 90,
            exposureLevel: .moderate,
            coordinates: [
                CLLocationCoordinate2D(latitude: -6.291, longitude: 106.641),
                CLLocationCoordinate2D(latitude: -6.301, longitude: 106.653)
            ]
        ),
        onDismiss: {}
    )
}
