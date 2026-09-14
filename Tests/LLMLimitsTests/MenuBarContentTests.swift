import XCTest
@testable import LLMLimits

final class MenuBarContentTests: XCTestCase {
    private func claude(_ accounts: [MenuBarAccount], overflow: Int = 0) -> MenuBarEntry {
        MenuBarEntry(provider: .claude, accounts: accounts, overflow: overflow)
    }

    @MainActor
    func testBothProvidersRenderIntoOneWiderImage() throws {
        let claudeOnly = MenuBarContent(entries: [claude([.init(label: "first", percent: 22)])])
        let codexOnly = MenuBarContent(entries: [
            MenuBarEntry(provider: .codex, accounts: [.init(label: "codex", percent: 0)]),
        ])
        let both = MenuBarContent(entries: [
            claude([.init(label: "first", percent: 22)]),
            MenuBarEntry(provider: .codex, accounts: [.init(label: "codex", percent: 0)]),
        ])

        let claudeImage = try XCTUnwrap(claudeOnly.renderImage())
        let codexImage = try XCTUnwrap(codexOnly.renderImage())
        let bothImage = try XCTUnwrap(both.renderImage())

        XCTAssertGreaterThan(bothImage.size.width, claudeImage.size.width + codexImage.size.width)
        XCTAssertEqual(bothImage.size.height, 18)
        XCTAssertTrue(bothImage.isTemplate)
        XCTAssertEqual(both.accessibilityText, "Claude 22% / Codex 0%")
        XCTAssertEqual(claudeOnly.accessibilityText, "Claude 22%")
        XCTAssertEqual(codexOnly.accessibilityText, "Codex 0%")
    }

    @MainActor
    func testTwoClaudeAccountsRenderInlineAndNameEachOne() throws {
        let single = MenuBarContent(entries: [claude([.init(label: "first", percent: 16)])])
        let paired = MenuBarContent(entries: [claude([
            .init(label: "first", percent: 16),
            .init(label: "second", percent: 96),
        ])])

        let singleImage = try XCTUnwrap(single.renderImage())
        let pairedImage = try XCTUnwrap(paired.renderImage())

        XCTAssertGreaterThan(pairedImage.size.width, singleImage.size.width)
        XCTAssertEqual(pairedImage.size.height, 18)
        // 계정이 여럿일 때만 어느 계정의 숫자인지 밝힌다.
        XCTAssertEqual(paired.accessibilityText, "Claude first 16% · second 96%")
    }

    @MainActor
    func testOverflowIsSummarizedInsteadOfWideningForever() throws {
        let content = MenuBarContent(entries: [claude(
            [
                .init(label: "a", percent: 1),
                .init(label: "b", percent: 2),
                .init(label: "c", percent: 3),
            ],
            overflow: 2
        )])

        XCTAssertEqual(content.accessibilityText, "Claude a 1% · b 2% · c 3% 외 2개")
        XCTAssertNotNil(content.renderImage())
    }

    @MainActor
    func testNoProvidersRenderFallback() throws {
        let content = MenuBarContent(entries: [])
        XCTAssertEqual(content.accessibilityText, "LLM Limits")
        XCTAssertNotNil(content.renderImage())
    }
}
