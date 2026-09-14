import Foundation

/// 소스(쿠키 / Orca / Codex CLI)가 서로 다른 응답을 내놓아도
/// 뷰는 이 한 가지 표현만 그린다.
struct UsageRow: Identifiable, Equatable {
    let id: String
    let title: String
    let metric: UsageMetric
    let windowMinutes: Int?

    init(id: String, title: String, metric: UsageMetric, windowMinutes: Int? = nil) {
        self.id = id
        self.title = title
        self.metric = metric
        self.windowMinutes = windowMinutes
    }

    /// 같은 한도가 두 소스에서 겹쳐 들어오면 첫 항목만 남긴다.
    static func deduplicated(_ rows: [UsageRow]) -> [UsageRow] {
        var seen = Set<String>()
        return rows.filter { seen.insert($0.id).inserted }
    }
}

enum UsageRowID {
    static let fiveHour = "five_hour"
    static let sevenDay = "seven_day"
    static let weeklyDesign = "weekly:claude_design"
    static let monthly = "monthly"

    /// 쿠키의 `limits[weekly_scoped]`와 Orca의 `fableWeekly`가
    /// 같은 한도를 가리키므로 id를 모델명으로 통일한다.
    static func weeklyModel(_ displayName: String) -> String {
        "weekly:\(displayName.lowercased())"
    }
}
