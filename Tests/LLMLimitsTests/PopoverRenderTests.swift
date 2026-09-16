import SwiftUI
import XCTest
@testable import LLMLimits

final class PopoverRenderTests: XCTestCase {
    private func entry(
        accountID: String,
        orgID: String,
        label: String,
        isActive: Bool,
        session: Double,
        weekly: Double,
        fable: Double,
        ageMinutes: Double
    ) -> OrcaSnapshot.Entry {
        let reset = Date().addingTimeInterval(3 * 3600)
        return OrcaSnapshot.Entry(
            accountID: accountID,
            orgID: orgID,
            label: label,
            isActive: isActive,
            rows: [
                UsageRow(id: UsageRowID.fiveHour, title: "5시간 세션", metric: .init(utilization: session, resetsAt: reset), windowMinutes: 300),
                UsageRow(id: UsageRowID.sevenDay, title: "주간 · 전체", metric: .init(utilization: weekly, resetsAt: reset.addingTimeInterval(86_400)), windowMinutes: 10_080),
                UsageRow(id: UsageRowID.weeklyModel("Fable"), title: "주간 · Fable", metric: .init(utilization: fable, resetsAt: reset.addingTimeInterval(86_400)), windowMinutes: 10_080),
            ],
            updatedAt: Date().addingTimeInterval(-ageMinutes * 60),
            error: nil,
            isFetching: false
        )
    }

    private var twoAccountSnapshot: OrcaSnapshot {
        OrcaSnapshot(
            claude: [
                entry(accountID: "acct-b", orgID: "org-b", label: "first@example.com", isActive: true, session: 28, weekly: 3, fable: 4, ageMinutes: 0.4),
                entry(accountID: "acct-a", orgID: "org-a", label: "second@example.com", isActive: false, session: 1, weekly: 96, fable: 73, ageMinutes: 30),
            ],
            codexSystemDefaultLabel: "second@example.com"
        )
    }

    private func codexUsage() throws -> CodexUsageData {
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
        return try JSONDecoder().decode(CodexUsageData.self, from: Data(json.utf8))
    }

    @MainActor
    private func render(_ view: some View, named name: String) throws -> NSImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage, "\(name) 렌더 실패")
        if let dir = ProcessInfo.processInfo.environment["LLM_LIMITS_RENDER_DIR"],
           let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        return image
    }

    @MainActor
    func testRendersBothClaudeAccountsAndCodexInOnePopover() throws {
        let service = UsageService.seeded(
            orca: twoAccountSnapshot,
            codexUsage: try codexUsage(),
            isCodexInstalled: true
        )

        XCTAssertEqual(service.claudeAccounts.count, 2)
        XCTAssertEqual(service.claudeAccounts.map(\.shortLabel), ["first", "second"])
        XCTAssertEqual(service.claudeAccounts.map(\.menuBarUtilization), [28, 96])
        XCTAssertEqual(service.codexAccounts.map(\.label), ["second@example.com"])
        XCTAssertEqual(service.activeAccountCount, 3)

        let image = try render(UsagePopoverView(service: service), named: "popover-two-accounts")
        XCTAssertEqual(image.size.width, 284)
        // 한 행이 한 줄로 줄어든 뒤에도 계정 2개 + Codex가 모두 들어가야 한다.
        XCTAssertGreaterThan(image.size.height, 200)
        XCTAssertLessThan(image.size.height, 400, "행이 다시 세 줄로 늘어나면 여기서 걸린다")

        // 다크 모드는 실제 팝오버처럼 어두운 바탕 위에 얹어야 대비를 볼 수 있다.
        _ = try render(
            UsagePopoverView(service: service)
                .background(Color(white: 0.13))
                .environment(\.colorScheme, .dark),
            named: "popover-two-accounts-dark"
        )
    }

    @MainActor
    func testRendersSingleAccountPopover() throws {
        let service = UsageService.seeded(
            orca: OrcaSnapshot(claude: [twoAccountSnapshot.claude[0]], codexSystemDefaultLabel: nil),
            isCodexInstalled: false
        )

        XCTAssertEqual(service.claudeAccounts.count, 1)
        let image = try render(UsagePopoverView(service: service), named: "popover-single-account")
        XCTAssertEqual(image.size.width, 284)
    }

    @MainActor
    func testRendersSettingsWithTwoAccounts() throws {
        let service = UsageService.seeded(
            orca: twoAccountSnapshot,
            credentials: [ClaudeCredential(orgId: "org-b", cookie: "cookie", label: "first@example.com")],
            cookieStates: ["org-b": .init(usage: nil, fetchedAt: nil)],
            isCodexInstalled: true
        )

        let image = try render(SettingsView(service: service), named: "settings-two-accounts")
        XCTAssertEqual(image.size.width, 404)
    }

    @MainActor
    func testResetColumnKeepsItsWidthInBothFormats() throws {
        let rows = twoAccountSnapshot.claude[0].rows

        let relative = VStack(spacing: 2) {
            ForEach(rows) { UsageRowView(row: $0, showsAbsoluteReset: false) }
        }
        .frame(width: 260)
        let absolute = VStack(spacing: 2) {
            ForEach(rows) { UsageRowView(row: $0, showsAbsoluteReset: true) }
        }
        .frame(width: 260)

        let relativeImage = try render(relative, named: "rows-relative")
        let absoluteImage = try render(absolute, named: "rows-absolute")

        // 형식을 바꿔도 행 높이와 폭이 흔들리면 안 된다.
        XCTAssertEqual(relativeImage.size, absoluteImage.size)
    }

    @MainActor
    func testResetColumnShowsTheDateByDefault() throws {
        // 메뉴바 패널에서는 툴팁이 뜨지 않으므로 리셋 시각이 기본으로 보여야 한다.
        UserDefaults.standard.removeObject(forKey: "showsAbsoluteReset")
        defer { UserDefaults.standard.removeObject(forKey: "showsAbsoluteReset") }

        let service = UsageService.seeded(orca: twoAccountSnapshot)
        _ = try render(UsagePopoverView(service: service), named: "popover-default-reset")

        let row = try XCTUnwrap(service.claudeAccounts.first?.rows.first)
        XCTAssertFalse(row.metric.resetsAtCompact.isEmpty)
        XCTAssertTrue(row.metric.resetsAtCompact.contains("/"), "날짜가 포함돼야 한다")
    }

    @MainActor
    func testRendersMenuBarLabelForTwoClaudeAccountsPlusCodex() throws {
        let service = UsageService.seeded(
            orca: twoAccountSnapshot,
            codexUsage: try codexUsage(),
            isCodexInstalled: true
        )

        // 계정마다 5시간 · 주간 · 모델별 주간 순서로 막대가 선다.
        XCTAssertEqual(
            service.menuBarEntries.map { $0.accounts.map(\.summary) },
            [
                ["5시간 28% · 주간 3% · Fable 4%", "5시간 1% · 주간 96% · Fable 73%"],
                // 이 Codex 픽스처는 주간 한도만 내려준다. 5시간 줄은 빈 트랙으로 남는다.
                ["주간 53%"],
            ]
        )

        let content = MenuBarContent(entries: service.menuBarEntries)
        let image = try render(content.environment(\.colorScheme, .light), named: "menubar-two-accounts")
        XCTAssertLessThan(image.size.width, 150, "메뉴바가 지나치게 넓어지면 안 된다")
    }

    @MainActor
    func testRendersEmptyStateWhenNoSourceIsAvailable() throws {
        let service = UsageService.seeded(orca: nil, orcaStatus: .notInstalled)

        XCTAssertTrue(service.claudeAccounts.isEmpty)
        XCTAssertTrue(service.codexAccounts.isEmpty)
        XCTAssertTrue(service.hasCheckedSources)

        _ = try render(UsagePopoverView(service: service), named: "popover-empty")
    }
}
