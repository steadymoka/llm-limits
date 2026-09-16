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

    /// 메뉴바 막대의 몇 번째 줄인지. Claude는 행 id가 정해져 있고,
    /// Codex는 한도마다 id가 달라 창 길이로 판단한다.
    var menuBarWindow: MenuBarWindow? {
        switch id {
        case UsageRowID.fiveHour: return .session
        case UsageRowID.sevenDay: return .weekly
        default: break
        }
        if id.hasPrefix(UsageRowID.weeklyModelPrefix) { return .modelWeekly }

        switch windowMinutes {
        case 300: return .session
        case 10_080: return .weekly
        default: return nil
        }
    }

    /// 좁은 자리에서 이 한도를 부르는 이름. 모델별 주간은 모델 이름이 핵심이다.
    var menuBarName: String {
        switch menuBarWindow {
        case .session: return "5시간"
        case .weekly: return "주간"
        case .modelWeekly: return title.components(separatedBy: " · ").last ?? title
        case nil: return title
        }
    }
}

/// 메뉴바 막대 한 줄. 줄 위치의 뜻은 Claude와 Codex에서 같아야 한다.
/// 그래야 같은 높이의 막대를 두 제공자에서 같은 의미로 읽을 수 있다.
enum MenuBarWindow: Int, CaseIterable {
    case session
    case weekly
    /// 모델별 주간(Fable·Sonnet·Claude Design). Codex에는 없다.
    case modelWeekly
}

enum UsageRowID {
    static let fiveHour = "five_hour"
    static let sevenDay = "seven_day"
    static let weeklyDesign = "weekly:claude_design"
    static let monthly = "monthly"
    static let weeklyModelPrefix = "weekly:"

    /// 쿠키의 `limits[weekly_scoped]`와 Orca의 `fableWeekly`가
    /// 같은 한도를 가리키므로 id를 모델명으로 통일한다.
    static func weeklyModel(_ displayName: String) -> String {
        "\(weeklyModelPrefix)\(displayName.lowercased())"
    }
}
