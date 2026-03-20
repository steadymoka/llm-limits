import Foundation

struct UsageData: Codable, Equatable {
    let fiveHour: UsageMetric?
    let sevenDay: UsageMetric?
    let sevenDaySonnet: UsageMetric?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
    }

    var maxUtilization: Double {
        [fiveHour?.utilization, sevenDay?.utilization, sevenDaySonnet?.utilization]
            .compactMap { $0 }
            .max() ?? 0
    }
}

struct UsageMetric: Codable, Equatable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        guard let resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetsAt) { return date }
        // fractional seconds 없는 포맷 fallback
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }

    var resetsAtRelative: String {
        guard let date = resetsAtDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    var resetsAtFormatted: String {
        guard let date = resetsAtDate else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "오늘 a h:mm"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'내일' a h:mm"
        } else {
            formatter.dateFormat = "M/d a h:mm"
        }
        return formatter.string(from: date)
    }
}
