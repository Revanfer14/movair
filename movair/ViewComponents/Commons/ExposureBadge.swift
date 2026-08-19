import SwiftUI

struct ExposureBadge: View {
    let level: ExposureLevel
    
    var showsAqi: Bool = true
    var badgeSize: String = "small"

    var body: some View {
        HStack(spacing: 4) {
            if showsAqi {
                Image(systemName: badgeIcon)
                    .font(.system(size: badgeSize == "small" ? 12 : 24, weight: .semibold))
            } else {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
            }
            
            Text(level.title)
                .font(badgeSize == "small" ? Font.Brand.footnote : Font.Brand.title2Bold)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 12)
        .padding(.vertical, showsAqi ? 8 : 4)
        .background(backgroundColor, in: Capsule())
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityLabel("Exposure \(level.title)")
    }
    
    private var badgeIcon: String {
        switch level {
        case .low: return "aqi.low"
        case .moderate: return "aqi.medium"
        case .high: return "aqi.medium"
        case .veryHigh: return "aqi.high"
        case .extreme: return "aqi.high"
        }
    }

    private var dotColor: Color {
        switch level {
        case .low: return Color.Brand.primaryGreen
        case .moderate: return Color.Brand.primaryYellow
        case .high: return Color.Brand.primaryOrange
        case .veryHigh: return Color.Brand.primaryRed
        case .extreme: return Color.Brand.primaryMaroon
        }
    }

    private var textColor: Color {
        switch level {
        case .low: return Color.Brand.primaryGreen
        case .moderate: return Color.Brand.primaryYellow
        case .high: return Color.Brand.primaryOrange
        case .veryHigh: return Color.Brand.primaryRed
        case .extreme: return Color.Brand.primaryMaroon
        }
    }

    private var backgroundColor: Color {
        switch level {
        case .low: return Color.Brand.secondaryGreen
        case .moderate: return Color.Brand.secondaryYellow
        case .high: return Color.Brand.secondaryOrange
        case .veryHigh: return Color.Brand.secondaryRed
        case .extreme: return Color.Brand.secondaryMaroon
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ExposureBadge(level: .low)
        ExposureBadge(level: .moderate, showsAqi: true)
        ExposureBadge(level: .high, showsAqi: false)
        ExposureBadge(level: .veryHigh, showsAqi: true, badgeSize: "big")
        ExposureBadge(level: .extreme, showsAqi: true, badgeSize: "big")
    }
}
