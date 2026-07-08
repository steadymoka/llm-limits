import Foundation

struct UsageData: Codable, Equatable {
    let fiveHour: UsageMetric?
    let sevenDay: UsageMetric?
    let sevenDaySonnet: UsageMetric?
    // Claude Design 사용량은 내부적으로 omelette 코드네임으로 노출된다
    let sevenDayOmelette: UsageMetric?
    // 모델별 주간 한도(Fable 등)는 limits 배열의 weekly_scoped 항목으로 내려온다
    let limits: [UsageLimit]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOmelette = "seven_day_omelette"
        case limits
    }

    var modelScopedWeeklyLimits: [UsageLimit] {
        (limits ?? []).filter { $0.kind == "weekly_scoped" && $0.scope?.model?.displayName != nil }
    }

    var maxUtilization: Double {
        let metrics = [fiveHour?.utilization, sevenDay?.utilization, sevenDaySonnet?.utilization, sevenDayOmelette?.utilization]
            .compactMap { $0 }
        let scoped = modelScopedWeeklyLimits.map(\.percent)
        return (metrics + scoped).max() ?? 0
    }
}

struct UsageLimit: Codable, Equatable, Hashable {
    let kind: String
    let percent: Double
    let resetsAt: String?
    let scope: LimitScope?

    enum CodingKeys: String, CodingKey {
        case kind
        case percent
        case resetsAt = "resets_at"
        case scope
    }

    var asMetric: UsageMetric {
        UsageMetric(utilization: percent, resetsAt: resetsAt)
    }
}

struct LimitScope: Codable, Equatable, Hashable {
    let model: LimitScopeModel?
}

struct LimitScopeModel: Codable, Equatable, Hashable {
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
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
