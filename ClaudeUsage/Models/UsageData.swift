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
        return ISO8601DateFormatter().date(from: resetsAt)
    }

    var resetsAtRelative: String {
        guard let date = resetsAtDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
