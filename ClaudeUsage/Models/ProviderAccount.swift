import Foundation

enum UsageProvider: String, Equatable, Hashable {
    case claude
    case codex
}

/// 사용량 한 묶음이 어디서 왔는지. 신선도 표시와 우선순위 판단에 쓴다.
enum UsageSource: Equatable {
    /// claude.ai 웹 API — 우리가 직접 호출하므로 항상 최신이고 행이 가장 상세하다.
    case cookie
    /// `orca account list --json` 스냅샷 — 계정 전부를 덮지만 Orca가 갱신한 시점의 값이다.
    case orca
    /// 설치된 Codex CLI의 app-server.
    case codexCLI

    var badgeName: String {
        switch self {
        case .cookie: return "LIVE"
        case .orca: return "ORCA"
        case .codexCLI: return "CLI"
        }
    }
}

struct AccountKey: Hashable {
    let provider: UsageProvider
    let id: String

    /// Claude 계정의 신원은 조직 UUID로 잡는다. 쿠키에서 해석한 orgId와
    /// Orca의 organizationUuid가 같은 값이라 두 소스를 이걸로 합칠 수 있다.
    static func claude(orgId: String) -> AccountKey {
        AccountKey(provider: .claude, id: orgId)
    }

    /// Orca에 등록됐지만 조직 UUID를 아직 모르는 계정.
    static func claude(orcaAccountId: String) -> AccountKey {
        AccountKey(provider: .claude, id: "orca-account:\(orcaAccountId)")
    }

    /// 로컬 Codex CLI 로그인. Orca의 systemDefault와 같은 계정을 가리킨다.
    static let localCodex = AccountKey(provider: .codex, id: "local")

    var storageID: String { "\(provider.rawValue)/\(id)" }

    private static let orcaAccountPrefix = "orca-account:"

    /// 쿠키를 바인딩할 수 있는 계정인지. Orca가 조직 UUID를 아직 모르는
    /// 계정은 쿠키와 맞춰볼 기준이 없다.
    var claudeOrgID: String? {
        guard provider == .claude, !id.hasPrefix(Self.orcaAccountPrefix) else { return nil }
        return id
    }
}

/// 팝오버·메뉴바가 그대로 그리는 표시 모델.
struct AccountCard: Identifiable, Equatable {
    let key: AccountKey
    var label: String
    var isActive: Bool
    var rows: [UsageRow]
    var planLabel: String?
    var source: UsageSource?
    var fetchedAt: Date?
    var isLoading: Bool
    var error: String?
    var isUnlimited: Bool

    init(
        key: AccountKey,
        label: String,
        isActive: Bool = false,
        rows: [UsageRow] = [],
        planLabel: String? = nil,
        source: UsageSource? = nil,
        fetchedAt: Date? = nil,
        isLoading: Bool = false,
        error: String? = nil,
        isUnlimited: Bool = false
    ) {
        self.key = key
        self.label = label
        self.isActive = isActive
        self.rows = rows
        self.planLabel = planLabel
        self.source = source
        self.fetchedAt = fetchedAt
        self.isLoading = isLoading
        self.error = error
        self.isUnlimited = isUnlimited
    }

    var id: AccountKey { key }

    /// 이메일에서 도메인을 떼어 좁은 자리에 쓰는 라벨.
    var shortLabel: String {
        guard let at = label.firstIndex(of: "@") else { return label }
        return String(label[label.startIndex..<at])
    }

    /// 메뉴바 대표값은 그 계정에서 가장 먼저 벽에 닿는 한도다.
    /// 메뉴바 라벨은 템플릿 이미지로 렌더되어 색으로 심각도를 전할 수 없으므로,
    /// 숫자 자체가 구속 조건이어야 한다. 세션이 1%인데 주간이 96%인 계정을
    /// 1%로 표시하면 계정을 갈아탈 판단을 망친다.
    var menuBarUtilization: Double? {
        rows.map(\.metric.utilization).max()
    }

    var maxUtilization: Double {
        menuBarUtilization ?? 0
    }

    /// 소스와 그 데이터가 몇 분 전 것인지. Orca 스냅샷은 캐시라 나이를 숨기지 않는다.
    /// Codex는 소스가 하나뿐이라 배지가 정보를 더하지 않는다.
    func sourceBadge(now: Date = .now) -> String? {
        guard let source, source != .codexCLI else { return nil }
        guard let fetchedAt else { return source.badgeName }

        let age = Int(now.timeIntervalSince(fetchedAt) / 60)
        // 우리가 직접 부르는 소스는 폴링 주기 안이면 그냥 최신이다.
        if source == .cookie, age < 6 { return source.badgeName }

        if age < 1 { return "\(source.badgeName) NOW" }
        if age < 60 { return "\(source.badgeName) \(age)m" }
        return "\(source.badgeName) \(age / 60)h"
    }
}
