import SwiftUI

struct RouteMetric: Identifiable {
    let id = UUID()
    let value: String
    let label: String
}

struct MapRouteMetricRow: View {
    let items: [RouteMetric]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                VStack(spacing: 4) {
                    Text(item.value)
                        .font(Font.Brand.bodyBold)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                    Text(item.label)
                        .font(Font.Brand.footnote)
                        .foregroundStyle(Color.Brand.darkgray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MapRouteMetricRow(items: [
        RouteMetric(value: "10.5 km", label: "Distance"),
        RouteMetric(value: "1h 40m", label: "Duration"),
        RouteMetric(value: "10 km/h", label: "Avg. speed")
    ])
    .padding()
}
