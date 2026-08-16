import SwiftUI

struct HistoryExposureGauge: View {
    let percent: Int
    var lineWidth: CGFloat = 14
    var size: CGFloat = 120
    var showsPercentLabel: Bool = true

    private var clamped: Double {
        min(1, max(0, Double(percent) / 100.0))
    }

    var body: some View {
        ZStack {
            // Track
            GaugeArc()
                .stroke(
                    Color.Brand.gray.opacity(0.35),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Progress
            GaugeArc()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.Brand.primaryOrange,
                            Color.Brand.primaryYellow.opacity(0.85)
                        ],
                        center: .center,
                        startAngle: .degrees(180),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            if showsPercentLabel {
                Text("\(percent)%")
                    .font(Font.Brand.title2Bold)
                    .foregroundStyle(Color.primary)
                    .offset(y: size * 0.26)
            }
        }
        .frame(width: size, height: size * 0.62)
        .accessibilityLabel("\(percent) percent of daily exposure")
    }
}

private struct GaugeArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height * 2) / 2
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        path.addArc(
            center: center,
            radius: radius - 2,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        HistoryExposureGauge(percent: 55, size: 100)
        HistoryExposureGauge(percent: 42, size: 140, showsPercentLabel: false)
    }
    .padding()
}
