import SwiftUI

struct TripShareCardView: View {
    static let cardSize = CGSize(width: 402, height: 874)

    let trip: TripSummary
    let mapImage: UIImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: mapImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Self.cardSize.width, height: Self.cardSize.height)
                .clipped()

            VStack(alignment: .leading, spacing: 0) {
                Text(trip.exposureLevel.title)
                    .font(Font.Brand.largeTitleBold)
                    .foregroundStyle(Color.Brand.black)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(trip.exposureUg) µg")
                        .font(Font.Brand.largeTitleBold)
                        .foregroundStyle(Color.Brand.black)
                    Text("/ \(trip.dailyBudgetUg) µg")
                        .font(Font.Brand.title2)
                        .foregroundStyle(Color.Brand.darkgray)
                }
                .padding(.top, 8)

                Text("Rute ini menghabiskan \(trip.dailyExposurePercent)% kuota napas bersih harianmu")
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

                Spacer()

                Text("Estimasi model CleanRoute · bukan pengukuran sensor")
                    .font(Font.Brand.footnote)
                    .foregroundStyle(Color.Brand.darkgray)
            }
            .padding(.top, 133)
            .padding(.leading, 27)
            .padding(.bottom, 32)
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .background(Color.Brand.white)
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
