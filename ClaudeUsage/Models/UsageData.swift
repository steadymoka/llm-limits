import Foundation

struct UsageData: Decodable, Equatable {
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

    /// claude.ai 응답을 소스 중립적인 표시 행으로 정규화한다.
    var rows: [UsageRow] {
        var rows = [UsageRow]()
        if let fiveHour {
            rows.append(UsageRow(id: UsageRowID.fiveHour, title: "5시간 세션", metric: fiveHour, windowMinutes: 300))
        }
        if let sevenDay {
            rows.append(UsageRow(id: UsageRowID.sevenDay, title: "주간 · 전체", metric: sevenDay, windowMinutes: 10_080))
        }
        if let sevenDaySonnet {
            rows.append(UsageRow(
                id: UsageRowID.weeklyModel("Sonnet"),
                title: "주간 · Sonnet",
                metric: sevenDaySonnet,
                windowMinutes: 10_080
            ))
        }
        if let sevenDayOmelette {
            rows.append(UsageRow(
                id: UsageRowID.weeklyDesign,
                title: "주간 · Claude Design",
                metric: sevenDayOmelette,
                windowMinutes: 10_080
            ))
        }
        for limit in modelScopedWeeklyLimits {
            let name = limit.scope?.model?.displayName ?? "모델"
            rows.append(UsageRow(
                id: UsageRowID.weeklyModel(name),
                title: "주간 · \(name)",
                metric: limit.asMetric,
                windowMinutes: 10_080
            ))
        }
        return UsageRow.deduplicated(rows)
    }

    var maxUtilization: Double {
        rows.map(\.metric.utilization).max() ?? 0
    }
}

struct UsageLimit: Decodable, Equatable, Hashable {
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
        UsageMetric(utilization: percent, resetsAt: resetsAt.flatMap(UsageMetric.parseTimestamp))
    }
}

struct LimitScope: Decodable, Equatable, Hashable {
    let model: LimitScopeModel?
}

struct LimitScopeModel: Decodable, Equatable, Hashable {
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

struct UsageMetric: Equatable {
    let utilization: Double
    let resetsAt: Date?

    init(utilization: Double, resetsAt: Date? = nil) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }
}

extension UsageMetric: Decodable {
    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let utilization = try container.decode(Double.self, forKey: .utilization)
        let raw = try container.decodeIfPresent(String.self, forKey: .resetsAt)
        self.init(utilization: utilization, resetsAt: raw.flatMap(Self.parseTimestamp))
    }

    /// 소스마다 다른 타임스탬프 표현을 경계에서 한 번만 Date로 바꾼다.
    static func parseTimestamp(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        // fractional seconds 없는 포맷 fallback
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func fromUnixSeconds(_ seconds: Int64?) -> Date? {
        seconds.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    static func fromUnixMilliseconds(_ milliseconds: Int64?) -> Date? {
        milliseconds.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
    }
}

extension UsageMetric {
    var resetsAtRelative: String {
        guard let resetsAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: resetsAt, relativeTo: .now)
    }

    /// 한 열에 들어가야 하므로 어느 시점이든 폭이 같은 형식으로 쓴다.
    var resetsAtCompact: String {
        guard let resetsAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: resetsAt)
    }

    var resetsAtFormatted: String {
        guard let resetsAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        let calendar = Calendar.current
        if calendar.isDateInToday(resetsAt) {
            formatter.dateFormat = "오늘 a h:mm"
        } else if calendar.isDateInTomorrow(resetsAt) {
            formatter.dateFormat = "'내일' a h:mm"
        } else {
            formatter.dateFormat = "M/d a h:mm"
        }
        return formatter.string(from: resetsAt)
    }
}
