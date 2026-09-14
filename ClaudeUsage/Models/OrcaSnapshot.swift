import Foundation

// MARK: - `orca account list --json` 응답

struct OrcaEnvelope: Decodable {
    let ok: Bool?
    let result: OrcaResult?
    let error: OrcaErrorPayload?
}

struct OrcaErrorPayload: Decodable {
    let message: String?
    let code: String?
}

struct OrcaResult: Decodable {
    let claude: OrcaProviderAccounts?
    let codex: OrcaProviderAccounts?
    let rateLimits: OrcaRateLimitsBundle?
}

struct OrcaProviderAccounts: Decodable {
    let accounts: [OrcaAccount]?
    let activeAccountId: String?
    let systemDefault: OrcaSystemDefault?
}

struct OrcaAccount: Decodable {
    let id: String
    let email: String?
    let organizationUuid: String?
    let organizationName: String?
    let authMethod: String?
}

struct OrcaSystemDefault: Decodable {
    let email: String?
    let providerAccountId: String?
    let hasAuth: Bool?
}

struct OrcaRateLimitsBundle: Decodable {
    let claude: OrcaRateLimits?
    let codex: OrcaRateLimits?
    let inactiveClaudeAccounts: [OrcaInactiveAccount]?
    let inactiveCodexAccounts: [OrcaInactiveAccount]?
}

struct OrcaInactiveAccount: Decodable {
    let accountId: String
    let rateLimits: OrcaRateLimits?
    let isFetching: Bool?
}

struct OrcaRateLimits: Decodable {
    let session: OrcaWindow?
    let weekly: OrcaWindow?
    let fableWeekly: OrcaWindow?
    let monthly: OrcaWindow?
    let updatedAt: Int64?
    let status: String?
    let error: String?
    let usageMetadata: OrcaUsageMetadata?

    var rows: [UsageRow] {
        var rows = [UsageRow]()
        if let session {
            rows.append(session.row(id: UsageRowID.fiveHour, title: "5시간 세션", fallbackWindow: 300))
        }
        if let weekly {
            rows.append(weekly.row(id: UsageRowID.sevenDay, title: "주간 · 전체", fallbackWindow: 10_080))
        }
        if let fableWeekly {
            rows.append(fableWeekly.row(
                id: UsageRowID.weeklyModel("Fable"),
                title: "주간 · Fable",
                fallbackWindow: 10_080
            ))
        }
        if let monthly {
            rows.append(monthly.row(id: UsageRowID.monthly, title: "월간", fallbackWindow: 43_200))
        }
        return rows
    }
}

struct OrcaUsageMetadata: Decodable {
    let source: String?
    let credentialSource: String?
    let authProvenance: String?

    private static let managedPrefix = "managed:"

    /// Orca는 활성 사용량이 어느 관리 계정에서 나왔는지를 이 문자열로 알려준다.
    var managedAccountId: String? {
        guard let authProvenance, authProvenance.hasPrefix(Self.managedPrefix) else { return nil }
        let id = String(authProvenance.dropFirst(Self.managedPrefix.count))
        return id.isEmpty ? nil : id
    }
}

struct OrcaWindow: Decodable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: Int64?

    func row(id: String, title: String, fallbackWindow: Int) -> UsageRow {
        UsageRow(
            id: id,
            title: title,
            // Orca의 resetsAt은 밀리초 epoch이다.
            metric: UsageMetric(utilization: usedPercent, resetsAt: UsageMetric.fromUnixMilliseconds(resetsAt)),
            windowMinutes: windowMinutes ?? fallbackWindow
        )
    }
}

// MARK: - 정규화된 스냅샷

struct OrcaSnapshot: Equatable {
    struct Entry: Equatable {
        let accountID: String
        let orgID: String?
        let label: String
        let isActive: Bool
        let rows: [UsageRow]
        let updatedAt: Date?
        let error: String?
        let isFetching: Bool

        var claudeKey: AccountKey {
            if let orgID, !orgID.isEmpty { return .claude(orgId: orgID) }
            return .claude(orcaAccountId: accountID)
        }
    }

    let claude: [Entry]
    /// Orca가 아는 로컬 Codex 로그인의 이메일. Codex 카드 라벨을 채우는 데만 쓴다.
    let codexSystemDefaultLabel: String?

    static let empty = OrcaSnapshot(claude: [], codexSystemDefaultLabel: nil)

    init(claude: [Entry], codexSystemDefaultLabel: String?) {
        self.claude = claude
        self.codexSystemDefaultLabel = codexSystemDefaultLabel
    }

    init(result: OrcaResult) {
        let accounts = result.claude?.accounts ?? []
        let activeAccountID = result.claude?.activeAccountId
        let bundle = result.rateLimits

        // 계정 id → 사용량. 활성 계정 사용량은 authProvenance로 귀속하고,
        // 그 정보가 없을 때만 activeAccountId를 믿는다.
        var limitsByAccount = [String: OrcaRateLimits]()
        var fetchingAccounts = Set<String>()

        for inactive in bundle?.inactiveClaudeAccounts ?? [] {
            if let limits = inactive.rateLimits {
                limitsByAccount[inactive.accountId] = limits
            }
            if inactive.isFetching == true {
                fetchingAccounts.insert(inactive.accountId)
            }
        }

        // 활성 사용량은 Orca가 방금 읽은 값이므로 비활성 캐시보다 우선한다.
        if let active = bundle?.claude {
            if let owner = active.usageMetadata?.managedAccountId {
                limitsByAccount[owner] = active
            } else if active.usageMetadata?.authProvenance == nil, let activeAccountID {
                // 예전 Orca는 provenance를 내려주지 않는다.
                limitsByAccount[activeAccountID] = active
            }
            // authProvenance가 있으나 managed:가 아니면 관리 계정이 아닌
            // 시스템 로그인의 사용량이므로 어떤 계정에도 붙이지 않는다.
        }

        var entries = accounts.map { account -> Entry in
            let limits = limitsByAccount[account.id]
            return Entry(
                accountID: account.id,
                orgID: account.organizationUuid,
                label: account.email ?? account.organizationName ?? "Claude 계정",
                isActive: account.id == activeAccountID,
                rows: limits?.rows ?? [],
                updatedAt: UsageMetric.fromUnixMilliseconds(limits?.updatedAt),
                error: limits?.error,
                isFetching: fetchingAccounts.contains(account.id)
            )
        }

        // 활성 계정이 앞, 나머지는 라벨 순. 폴링마다 순서가 흔들리면 안 된다.
        entries.sort { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }

        self.init(
            claude: entries,
            codexSystemDefaultLabel: result.codex?.systemDefault?.email
        )
    }
}
