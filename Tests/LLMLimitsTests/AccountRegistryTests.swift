import XCTest
@testable import LLMLimits

final class AccountRegistryTests: XCTestCase {
    private let cookieUsageJSON = """
    {
      "five_hour": { "utilization": 22.5, "resets_at": "2026-09-14T16:50:00.973Z" },
      "seven_day": { "utilization": 30, "resets_at": "2026-09-19T11:00:00Z" },
      "seven_day_sonnet": { "utilization": 12, "resets_at": null },
      "seven_day_omelette": { "utilization": 5, "resets_at": null },
      "limits": [
        {
          "kind": "weekly_scoped",
          "percent": 44,
          "resets_at": "2026-09-19T11:00:00Z",
          "scope": { "model": { "display_name": "Fable" } }
        },
        { "kind": "five_hour", "percent": 22.5, "resets_at": null, "scope": null }
      ]
    }
    """

    private func cookieUsage() throws -> UsageData {
        try JSONDecoder().decode(UsageData.self, from: Data(cookieUsageJSON.utf8))
    }

    private func orcaEntry(
        accountID: String,
        orgID: String?,
        label: String,
        isActive: Bool,
        session: Double,
        weekly: Double
    ) -> OrcaSnapshot.Entry {
        OrcaSnapshot.Entry(
            accountID: accountID,
            orgID: orgID,
            label: label,
            isActive: isActive,
            rows: [
                UsageRow(id: UsageRowID.fiveHour, title: "5시간 세션", metric: .init(utilization: session), windowMinutes: 300),
                UsageRow(id: UsageRowID.sevenDay, title: "주간 · 전체", metric: .init(utilization: weekly), windowMinutes: 10_080),
            ],
            updatedAt: Date(timeIntervalSince1970: 1_789_354_765),
            error: nil,
            isFetching: false
        )
    }

    func testShowsEveryOrcaAccountWithoutAnyCookie() {
        let snapshot = OrcaSnapshot(
            claude: [
                orcaEntry(accountID: "acct-b", orgID: "org-b", label: "second@example.com", isActive: true, session: 16, weekly: 2),
                orcaEntry(accountID: "acct-a", orgID: "org-a", label: "first@example.com", isActive: false, session: 1, weekly: 96),
            ],
            codexSystemDefaultLabel: nil
        )

        let cards = AccountRegistry.claudeCards(credentials: [], cookieStates: [:], orca: snapshot)

        XCTAssertEqual(cards.map(\.label), ["second@example.com", "first@example.com"])
        XCTAssertEqual(cards.map(\.source), [.orca, .orca])
        // 메뉴바 값은 그 계정에서 가장 먼저 닿는 한도다. 두 번째 계정의 주간 96%가
        // 세션 1% 뒤에 숨으면 계정을 갈아탈 판단을 할 수 없다.
        XCTAssertEqual(cards.map(\.menuBarUtilization), [16, 96])
    }

    func testCookieUpgradesTheMatchingAccountAndDoesNotDuplicateIt() throws {
        let snapshot = OrcaSnapshot(
            claude: [
                orcaEntry(accountID: "acct-b", orgID: "org-b", label: "second@example.com", isActive: true, session: 16, weekly: 2),
                orcaEntry(accountID: "acct-a", orgID: "org-a", label: "first@example.com", isActive: false, session: 1, weekly: 96),
            ],
            codexSystemDefaultLabel: nil
        )
        let fetchedAt = Date(timeIntervalSince1970: 1_789_400_000)
        let cards = AccountRegistry.claudeCards(
            credentials: [ClaudeCredential(orgId: "org-b", cookie: "c", label: "second@example.com")],
            cookieStates: ["org-b": .init(usage: try cookieUsage(), fetchedAt: fetchedAt)],
            orca: snapshot
        )

        XCTAssertEqual(cards.count, 2, "같은 계정이 두 소스에 있어도 카드는 하나다")
        let upgraded = try XCTUnwrap(cards.first)
        XCTAssertEqual(upgraded.source, .cookie)
        XCTAssertEqual(upgraded.fetchedAt, fetchedAt)
        XCTAssertEqual(upgraded.rows.map(\.id), [
            UsageRowID.fiveHour,
            UsageRowID.sevenDay,
            UsageRowID.weeklyModel("Sonnet"),
            UsageRowID.weeklyDesign,
            UsageRowID.weeklyModel("Fable"),
        ])
        // 승격되지 않은 계정은 Orca 값을 그대로 쓴다.
        XCTAssertEqual(cards.last?.source, .orca)
        XCTAssertEqual(cards.last?.maxUtilization, 96)
    }

    func testCookieFailureFallsBackToOrcaRows() {
        let snapshot = OrcaSnapshot(
            claude: [orcaEntry(accountID: "acct-b", orgID: "org-b", label: "second@example.com", isActive: true, session: 16, weekly: 2)],
            codexSystemDefaultLabel: nil
        )

        let cards = AccountRegistry.claudeCards(
            credentials: [ClaudeCredential(orgId: "org-b", cookie: "c", label: nil)],
            cookieStates: ["org-b": .init(error: "쿠키가 만료되었습니다")],
            orca: snapshot
        )

        let card = cards[0]
        XCTAssertEqual(card.source, .orca, "쿠키가 실패해도 Orca 값으로 계속 보여준다")
        XCTAssertEqual(card.menuBarUtilization, 16)
        XCTAssertEqual(card.error, "쿠키가 만료되었습니다")
    }

    func testCookieOnlyAccountStillAppearsWhenOrcaIsUnavailable() throws {
        let cards = AccountRegistry.claudeCards(
            credentials: [ClaudeCredential(orgId: "org-x1234567", cookie: "c", label: nil)],
            cookieStates: ["org-x1234567": .init(usage: try cookieUsage(), fetchedAt: .now)],
            orca: nil
        )

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].label, "조직 org-x123")
        XCTAssertEqual(cards[0].source, .cookie)
        XCTAssertEqual(cards[0].menuBarUtilization, 44, "가장 높은 한도인 Fable 주간이 대표값이 된다")
    }

    func testCodexCardTakesItsLabelFromOrcaButKeepsCLIData() throws {
        let json = #"""
        {
          "rateLimits": {
            "limitId": "codex",
            "limitName": null,
            "primary": { "usedPercent": 53, "windowDurationMins": 10080, "resetsAt": 1789805461 },
            "secondary": null,
            "credits": null,
            "planType": "plus"
          },
          "rateLimitsByLimitId": null
        }
        """#
        let usage = try JSONDecoder().decode(CodexUsageData.self, from: Data(json.utf8))

        let cards = AccountRegistry.codexCards(
            usage: usage,
            error: nil,
            fetchedAt: nil,
            isLoading: false,
            isInstalled: true,
            orcaLabel: "codex@example.com"
        )

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].label, "codex@example.com")
        XCTAssertEqual(cards[0].planLabel, "PLUS")
        XCTAssertEqual(cards[0].source, .codexCLI)
        XCTAssertEqual(cards[0].menuBarUtilization, 53)
    }

    func testNoCodexCardWhenCLIIsMissing() {
        let cards = AccountRegistry.codexCards(
            usage: nil,
            error: nil,
            fetchedAt: nil,
            isLoading: false,
            isInstalled: false,
            orcaLabel: nil
        )

        XCTAssertTrue(cards.isEmpty)
    }

    func testOrcaAccountWithoutOrganizationIdGetsItsOwnKey() {
        let snapshot = OrcaSnapshot(
            claude: [orcaEntry(accountID: "acct-z", orgID: nil, label: "third@example.com", isActive: false, session: 3, weekly: 4)],
            codexSystemDefaultLabel: nil
        )

        let cards = AccountRegistry.claudeCards(credentials: [], cookieStates: [:], orca: snapshot)

        XCTAssertEqual(cards[0].key, AccountKey.claude(orcaAccountId: "acct-z"))
        XCTAssertNil(cards[0].key.claudeOrgID, "조직 UUID를 모르면 쿠키와 맞춰볼 수 없다")
    }
}
