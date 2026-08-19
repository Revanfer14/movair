import SwiftUI

struct TripShareCardView: View {
    static let cardSize = CGSize(width: 402, height: 874)
    static let mapContentInsets = UIEdgeInsets(top: 210, left: 150, bottom: 90, right: 32)

    let trip: TripSummary
    let mapImage: UIImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: mapImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Self.cardSize.width, height: Self.cardSize.height)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: Color.Brand.white.opacity(0.95), location: 0.0),
                    .init(color: Color.Brand.white.opacity(0.80), location: 0.34),
                    .init(color: Color.Brand.white.opacity(0.0), location: 0.78)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Self.cardSize.width, height: Self.cardSize.height)
            .allowsHitTesting(false)

            LinearGradient(
                stops: [
                    .init(color: Color.Brand.white.opacity(0.0), location: 0.0),
                    .init(color: Color.Brand.white.opacity(0.92), location: 1.0)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.82),
                endPoint: .bottom
            )
            .frame(width: Self.cardSize.width, height: Self.cardSize.height)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                Text(trip.exposureLevel.title)
                    .font(Font.Brand.largeTitleBold)
                    .fontWeight(exposureTitleFontWeight)
                    .foregroundStyle(trip.exposureLevel.primaryColor)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(trip.exposureUg) µg")
                        .font(Font.Brand.largeTitleBold)
                        .foregroundStyle(Color.Brand.black)
                    Text("/ \(trip.dailyBudgetUg) µg")
                        .font(Font.Brand.title2)
                        .foregroundStyle(Color.Brand.darkgray)
                }
                .padding(.top, 8)

                (
                    Text("Rute ini menghabiskan ") +
                    Text("\(trip.dailyExposurePercent)%").bold() +
                    Text(" kuota napas bersih harianmu")
                )
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .frame(maxWidth: 262, alignment: .leading)

                VStack(alignment: .leading, spacing: 42) {
                    statBlock(value: trip.distanceLabel, label: "Distance")
                    statBlock(value: trip.speedLabel, label: "Avg. speed")
                    statBlock(value: trip.durationLabel, label: "Duration")
                }
                .padding(.top, 68)
            }
            .padding(.top, 133)
            .padding(.leading, 27)
            .padding(.bottom, 32)
            .padding(.trailing, 27)

            Text("GoWays")
                .font(Font.Brand.footnoteBold)
                .foregroundStyle(Color.Brand.darkgray)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 40)
                .padding(.bottom, 40)
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .background(Color.Brand.white)
        .environment(\.colorScheme, .light)
    }

    private var exposureTitleFontWeight: Font.Weight {
        switch trip.exposureLevel {
        case .high, .extreme:
            return .heavy
        case .low, .moderate, .veryHigh:
            return .bold
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(Font.Brand.largeTitleBold)
                .foregroundStyle(Color.Brand.black)
            Text(label)
                .font(Font.Brand.footnote)
                .foregroundStyle(Color.Brand.darkgray)
            Rectangle()
                .fill(Color.Brand.gray)
                .frame(width: 60, height: 1)
        }
    }
}

#Preview {
    TripShareCardView(
        trip: TripSummary(
            originTitle: "Green Office Park",
            destinationTitle: "BXChange Mall",
            distanceKm: 10.5,
            durationMinutes: 90,
            averageSpeedKmh: 10,
            exposureUg: 110,
            exposureLevel: .extreme
        ),
        mapImage: UIImage()
    )
}
