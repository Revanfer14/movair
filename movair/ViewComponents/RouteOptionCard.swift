import SwiftUI

struct RouteOptionCard: View {
    let route: RouteOption
    let isSelected: Bool

    var body: some View {
        Group {
            if isSelected {
                expandedCard
            } else {
                compactCard
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider().opacity(0.25)
            stats
        }
        .padding(16)
        .padding(.top, route.isRecommended ? 4 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.Brand.blue900.opacity(0.55), lineWidth: 1.5)
        }
        .overlay(alignment: .topTrailing) {
            if route.isRecommended {
                recommendedBadge
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var compactCard: some View {
        HStack(alignment: .center, spacing: 10) {
            distanceBlock

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(route.title)
                        .font(Font.Brand.bodyBold)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    if route.isLonger {
                        Text("· More Distance")
                            .font(Font.Brand.footnote)
                            .foregroundStyle(Color.Brand.darkgray)
                            .lineLimit(1)
                    }
                }

                Text(route.pollutionDeltaLabel)
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            distanceBlock

            VStack(alignment: .leading, spacing: 2) {
                Text(route.title)
                    .font(Font.Brand.bodyBold)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(route.pollutionDeltaLabel)
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
                    .lineLimit(1)
            }
        }
    }

    private var distanceBlock: some View {
        VStack(spacing: 0) {
            Text(route.distanceLabel)
                .font(Font.Brand.title2Bold)
                .foregroundStyle(Color.primary)
            Text("KM")
                .font(Font.Brand.footnoteBold)
                .foregroundStyle(Color.Brand.darkgray)
        }
        .frame(minWidth: 36)
        .multilineTextAlignment(.center)
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Route Statistic")
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.Brand.darkgray)

            HStack(alignment: .top, spacing: 0) {
                statColumn(
                    value: "\(route.distanceLabel) km",
                    label: "Distance"
                )
                .frame(maxWidth: .infinity)

                statColumn(
                    value: route.durationLabel,
                    label: "Duration"
                )
                .frame(maxWidth: .infinity)

                exposureColumn
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func statColumn(value: String, label: String) -> some View {
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
        .frame(maxWidth: .infinity)
    }

    private var exposureColumn: some View {
        VStack(spacing: 4) {
            Text(route.exposureLabel)
                .font(Font.Brand.bodyBold)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
            Text("Est. Exposure")
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.Brand.darkgray)
                .multilineTextAlignment(.center)
            ExposureBadge(level: route.exposureLevel, showsAqi: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var recommendedBadge: some View {
        Text("Recommended")
            .font(Font.Brand.footnoteBold)
            .foregroundStyle(Color.Brand.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16,
                    style: .continuous
                )
                .fill(Color.Brand.blue900)
            )
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.35).ignoresSafeArea()
        VStack(spacing: 12) {
            RouteOptionCard(
                route: RouteOption(
                    title: "Cleaner Route",
                    distanceKm: 42,
                    durationMinutes: 170,
                    exposureRangeUg: 150...160,
                    exposureLevel: .high,
                    pollutionDeltaPercent: -10,
                    isRecommended: true,
                    coordinates: []
                ),
                isSelected: true
            )
            RouteOptionCard(
                route: RouteOption(
                    title: "Longer Route",
                    distanceKm: 47,
                    durationMinutes: 195,
                    exposureRangeUg: 170...185,
                    exposureLevel: .high,
                    pollutionDeltaPercent: 20,
                    isLonger: true,
                    coordinates: []
                ),
                isSelected: false
            )
        }
        .padding()
    }
}
