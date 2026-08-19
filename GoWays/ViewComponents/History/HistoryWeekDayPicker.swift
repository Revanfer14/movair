import SwiftUI

struct HistoryWeekDayPicker: View {
    let weekDates: [Date]
    let exposures: [Int?]
    @Binding var selectedDate: Date

    private let daySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                let exposure = index < exposures.count ? exposures[index] : nil

                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 8) {
                        Text(daySymbols[safe: index] ?? "")
                            .font(Font.Brand.footnoteBold)
                            .foregroundStyle(isSelected ? Color.Brand.labelPrimary : Color.Brand.darkgray)

                        dayIndicator(date: date, exposure: exposure, isSelected: isSelected)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(daySymbols[safe: index] ?? "")")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func dayIndicator(date: Date, exposure: Int?, isSelected: Bool) -> some View {
        if let exposure, exposure > 0 {
            // Icon changes based on exposure level
            let level = ExposureLevel.from(exposureUg: exposure)
            Image(systemName: level.aqiSymbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(level.primaryColor)
                .frame(width: 30, height: 30)
                .background(level.secondaryColor, in: Circle())
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(level.primaryColor, lineWidth: 2)
                    }
                }
        } else {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(Font.Brand.footnoteBold)
                .foregroundStyle(isSelected ? Color.Brand.white : Color.Brand.blue900)
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(isSelected ? Color.Brand.blue900 : Color.Brand.blue100)
                )
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    let dates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    return HistoryWeekDayPicker(
        weekDates: dates,
        exposures: [40, nil, 70, 95, nil, nil, nil],
        selectedDate: .constant(today)
    )
    .padding()
}
