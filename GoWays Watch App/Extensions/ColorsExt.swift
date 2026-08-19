import SwiftUI

extension Color {
    enum Brand {
        static let blue50 = Color(hex: "#EEF8FF")
        static let blue100 = Color(hex: "#D8F0FF")
        static let blue200 = Color(hex: "#BAE5FF")
        static let blue300 = Color(hex: "#8BD6FF")
        static let blue400 = Color(hex: "#54BFFF")
        static let blue500 = Color(hex: "#2DA2FF")
        static let blue600 = Color(hex: "#1685FA")
        static let blue700 = Color(hex: "#0F6DE6")
        static let blue800 = Color(hex: "#1357BA")
        static let blue900 = Color(hex: "#164C92")
        static let blue950 = Color(hex: "#16386A")

        // watchOS
        static let white     = Color(hex: "#F2F2F7")
        static let lightgray = Color(hex: "#2C2C2E")
        static let gray      = Color(hex: "#48484A")
        static let darkgray  = Color(hex: "#EBEBF5")
        static let black     = Color(hex: "#FFFFFF")

        static let labelPrimary = Color(hex: "#FFFFFF")

        static let primaryMaroon = Color(hex: "#8A0002")
        static let secondaryMaroon = Color(hex: "#3A1414")

        static let primaryRed = Color(hex: "#FF383C")
        static let secondaryRed = Color(hex: "#3A1616")

        static let primaryOrange = Color(hex: "#FF7800")
        static let secondaryOrange = Color(hex: "#3A2712")

        static let primaryYellow = Color(hex: "#DD8C00")
        static let secondaryYellow = Color(hex: "#3A3212")

        static let primaryGreen = Color(hex: "#34C759")
        static let secondaryGreen = Color(hex: "#123A1D")
    }
}

extension Color {
    init(hex: String) {
        let (r, g, b) = Color.rgb(from: hex)
        self.init(red: r, green: g, blue: b)
    }

    private static func rgb(from hex: String) -> (CGFloat, CGFloat, CGFloat) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        return (r, g, b)
    }
}
