import XCTest
@testable import LLMLimits

final class MenuBarContentTests: XCTestCase {
    private func account(
        _ label: String,
        session: Int? = nil,
        weekly: Int? = nil,
        model: (String, Int)? = nil
    ) -> MenuBarAccount {
        var bars = [MenuBarBar]()
        if let session { bars.append(MenuBarBar(window: .session, name: "5시간", percent: session)) }
        if let weekly { bars.append(MenuBarBar(window: .weekly, name: "주간", percent: weekly)) }
        if let model { bars.append(MenuBarBar(window: .modelWeekly, name: model.0, percent: model.1)) }
        return MenuBarAccount(label: label, bars: bars)
    }

    private func claude(_ accounts: [MenuBarAccount], overflow: Int = 0) -> MenuBarEntry {
        MenuBarEntry(provider: .claude, accounts: accounts, overflow: overflow)
    }

    private func codex(_ accounts: [MenuBarAccount]) -> MenuBarEntry {
        MenuBarEntry(provider: .codex, accounts: accounts)
    }

    @MainActor
    func testBothProvidersRenderIntoOneWiderImage() throws {
        let claudeAccount = account("first", session: 35, weekly: 62, model: ("Fable", 88))
        let codexAccount = account("codex", session: 20, weekly: 40)

        let claudeOnly = MenuBarContent(entries: [claude([claudeAccount])])
        let codexOnly = MenuBarContent(entries: [codex([codexAccount])])
        let both = MenuBarContent(entries: [claude([claudeAccount]), codex([codexAccount])])

        let claudeImage = try XCTUnwrap(claudeOnly.renderImage())
        let codexImage = try XCTUnwrap(codexOnly.renderImage())
        let bothImage = try XCTUnwrap(both.renderImage())

        XCTAssertGreaterThan(bothImage.size.width, claudeImage.size.width + codexImage.size.width)
        XCTAssertEqual(bothImage.size.height, 18)
        XCTAssertTrue(bothImage.isTemplate)
        XCTAssertEqual(
            both.accessibilityText,
            "Claude 5시간 35% · 주간 62% · Fable 88%\nCodex 5시간 20% · 주간 40%"
        )
    }

    @MainActor
    func testTwoClaudeAccountsRenderInlineAndNameEachOne() throws {
        let first = account("first", session: 35, weekly: 62, model: ("Fable", 88))
        let second = account("second", session: 10, weekly: 96, model: ("Fable", 40))

        let single = MenuBarContent(entries: [claude([first])])
        let paired = MenuBarContent(entries: [claude([first, second])])

        let singleImage = try XCTUnwrap(single.renderImage())
        let pairedImage = try XCTUnwrap(paired.renderImage())

        XCTAssertGreaterThan(pairedImage.size.width, singleImage.size.width)
        XCTAssertEqual(pairedImage.size.height, 18)
        // 계정이 여럿일 때만 어느 계정의 막대인지 밝힌다.
        XCTAssertEqual(
            paired.accessibilityText,
            "Claude first 5시간 35% · 주간 62% · Fable 88% / second 5시간 10% · 주간 96% · Fable 40%"
        )
    }

    /// 막대는 계정마다 같은 폭을 차지해야 한다. 값이 커서 넓어지면
    /// 사용량이 오를 때마다 메뉴바 아이콘 위치가 흔들린다.
    @MainActor
    func testBarWidthDoesNotDependOnUsage() throws {
        let empty = MenuBarContent(entries: [claude([account("a", session: 0, weekly: 0, model: ("Fable", 0))])])
        let full = MenuBarContent(entries: [claude([account("a", session: 100, weekly: 100, model: ("Fable", 100))])])
        let missingWindow = MenuBarContent(entries: [claude([account("a", session: 40)])])

        let emptyImage = try XCTUnwrap(empty.renderImage())
        let fullImage = try XCTUnwrap(full.renderImage())
        let missingImage = try XCTUnwrap(missingWindow.renderImage())

        XCTAssertEqual(emptyImage.size.width, fullImage.size.width)
        // 없는 창은 빈 트랙으로 자리를 지킨다. 그래야 줄 위치의 뜻이 흔들리지 않는다.
        XCTAssertEqual(missingImage.size.width, fullImage.size.width)
        XCTAssertEqual(missingImage.size.height, 18)
    }

    /// 100%를 넘겨 들어와도 막대가 트랙을 넘지 않는다.
    func testOverflowingPercentIsClampedToFullBar() {
        XCTAssertEqual(MenuBarBar(window: .weekly, name: "주간", percent: 130).fill, 1)
        XCTAssertEqual(MenuBarBar(window: .weekly, name: "주간", percent: -5).fill, 0)
        XCTAssertEqual(MenuBarBar(window: .weekly, name: "주간", percent: 50).fill, 0.5)
    }

    @MainActor
    func testOverflowIsSummarizedInsteadOfWideningForever() throws {
        let content = MenuBarContent(entries: [claude(
            [
                account("a", session: 1, weekly: 2, model: ("Fable", 3)),
                account("b", session: 2, weekly: 3, model: ("Fable", 4)),
                account("c", session: 3, weekly: 4, model: ("Fable", 5)),
            ],
            overflow: 2
        )])

        XCTAssertTrue(content.accessibilityText.hasSuffix("외 2개"), content.accessibilityText)
        XCTAssertNotNil(content.renderImage())
    }

    /// 메뉴바 아이콘은 알파만 남는 템플릿 이미지다. Codex 칩 안의 `>_`를
    /// 색으로 칠하면 여기서 통째로 검은 사각형이 된다.
    @MainActor
    func testCodexChipKeepsItsPromptPunchedOut() throws {
        let content = MenuBarContent(entries: [codex([account("codex", session: 20, weekly: 40)])])
        let image = try XCTUnwrap(content.renderImage())
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))

        // 칩은 18pt 높이 안의 13pt 사각형으로, 라벨 맨 왼쪽에 놓인다.
        let scale = CGFloat(bitmap.pixelsWide) / image.size.width
        let inset = Int(3 * scale)
        let chip = Int(13 * scale)
        let top = Int((18 - 13) / 2 * scale)

        var opaque = 0
        var clear = 0
        for x in inset..<(chip - inset) {
            for y in (top + inset)..<(top + chip - inset) {
                let alpha = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
                if alpha > 0.9 { opaque += 1 }
                if alpha < 0.1 { clear += 1 }
            }
        }

        XCTAssertGreaterThan(opaque, 0, "칩 바탕이 사라졌다")
        XCTAssertGreaterThan(clear, 0, "칩 안의 >_ 가 뚫려 있지 않다")
    }

    @MainActor
    func testNoProvidersRenderFallback() throws {
        let content = MenuBarContent(entries: [])
        XCTAssertEqual(content.accessibilityText, "LLM Limits")
        XCTAssertNotNil(content.renderImage())
    }
}
