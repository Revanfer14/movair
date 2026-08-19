import Foundation

enum WIBTime {
    static let timeZone = TimeZone(identifier: "Asia/Jakarta") ?? .current

    static func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func hourOfDay(for date: Date) -> Int {
        calendar().component(.hour, from: date)
    }

    static func isWeekend(for date: Date) -> Int {
        let weekday = calendar().component(.weekday, from: date)
        return weekday == 1 || weekday == 7 ? 1 : 0
    }

    static func iso8601String(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
