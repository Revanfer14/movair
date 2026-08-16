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

        static let white     = Color(light: "#FFFFFF", dark: "#F2F2F7")
        static let lightgray = Color(light: "#F6F6F6", dark: "#2C2C2E")
        static let gray      = Color(light: "#C7C7CC", dark: "#48484A")
        static let darkgray  = Color(light: "#3C3C43", dark: "#EBEBF5")
        static let black     = Color(light: "#000000", dark: "#FFFFFF")

        static let labelPrimary = Color(light: "#164C92", dark: "#FFFFFF")
        
        static let primaryMaroon = Color(hex: "#8A0002")
        static let secondaryMaroon = Color(light: "#FFE7E7", dark: "#3A1414")

        static let primaryRed = Color(hex: "#FF383C")
        static let secondaryRed = Color(light: "#FFECEC", dark: "#3A1616")

        static let primaryOrange = Color(hex: "#FF7800")
        static let secondaryOrange = Color(light: "#FFF3E9", dark: "#3A2712")

        static let primaryYellow = Color(hex: "#DD8C00")
        static let secondaryYellow = Color(light: "#FFF5CE", dark: "#3A3212")

        static let primaryGreen = Color(hex: "#34C759")
        static let secondaryGreen = Color(light: "#E6FFEC", dark: "#123A1D")
    }
}

extension Color {
    init(hex: String) {
        let (r, g, b) = Color.rgb(from: hex)
        self.init(red: r, green: g, blue: b)
    }

    init(light: String, dark: String) {
        self.init(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            let (r, g, b) = Color.rgb(from: hex)
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
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
