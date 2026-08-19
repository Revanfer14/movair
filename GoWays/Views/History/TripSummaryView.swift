import SwiftUI
import MapKit

struct TripSummaryView: View {
    let trip: TripSummary
    var onDismiss: () -> Void

    @State private var recenterTrigger = false
    @State private var shareImage: UIImage?
    @State private var isRenderingShareCard = false
    @State private var isShareSheetPresented = false
    @State private var shareErrorMessage: String?

    private let shareImageRenderer: TripShareImageRendering = TripShareImageRenderer()

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
                HStack(spacing: 12) {
                    shareButton
                    PrimaryButton(title: "Got it", action: onDismiss)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isShareSheetPresented) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
        .alert(
            "Couldn't create share image",
            isPresented: Binding(
                get: { shareErrorMessage != nil },
                set: { if !$0 { shareErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { shareErrorMessage = nil }
        } message: {
            Text(shareErrorMessage ?? "")
        }
    }

    private var shareButton: some View {
        Button(action: shareTrip) {
            Group {
                if isRenderingShareCard {
                    ProgressView()
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(Font.Brand.bodyBold)
                }
            }
            .frame(width: 52, height: 52)
            .foregroundStyle(Color.Brand.labelPrimary)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isRenderingShareCard || trip.displayCoordinates.count < 2)
        .opacity(trip.displayCoordinates.count < 2 ? 0.5 : 1)
        .accessibilityLabel("Share ride")
    }

    private func shareTrip() {
        guard !isRenderingShareCard else { return }
        isRenderingShareCard = true
        Task {
            defer { isRenderingShareCard = false }
            do {
                shareImage = try await shareImageRenderer.makeImage(for: trip)
                isShareSheetPresented = true
            } catch {
                shareErrorMessage = "Couldn't render this ride as an image. Please try again."
            }
        }
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

                Text(trip.isMeasuredExposure ? "Your Measured Exposure" : "Your Estimated Exposure")
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

                Text("of your daily exposure used on this ride")
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

    private var originMarkerCoordinate: CLLocationCoordinate2D? {
        trip.originCoordinate ?? trip.displayCoordinates.first
    }

    private var destinationMarkerCoordinate: CLLocationCoordinate2D? {
        trip.destinationCoordinate ?? trip.displayCoordinates.last
    }

    private var traceCaption: String {
        trip.hasActualTrace
            ? "GPS trace recorded during your ride"
            : "Planned route — GPS trace not available"
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
                centerCoordinate: trip.displayCoordinates.first,
                showsUserLocation: false,
                routeCoordinates: trip.displayCoordinates,
                plannedRouteCoordinates: trip.hasActualTrace ? trip.coordinates : [],
                isTraceMeasured: trip.hasActualTrace,
                breaksTraceAtGaps: true,
                originCoordinate: originMarkerCoordinate,
                destinationCoordinate: destinationMarkerCoordinate,
                fitsRouteInView: true,
                routeEdgePadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
                showsOriginMarker: true
            )
            .frame(height: 224)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Text(trip.routeTitle)
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(traceCaption)
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
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
