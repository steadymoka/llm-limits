import XCTest
@testable import LLMLimits

final class MenuBarContentTests: XCTestCase {
    @MainActor
    func testBothProvidersRenderIntoOneWiderImage() throws {
        let claude = MenuBarContent(claude: 22, codex: nil)
        let codex = MenuBarContent(claude: nil, codex: 0)
        let both = MenuBarContent(claude: 22, codex: 0)
        let claudeImage = try XCTUnwrap(claude.renderImage())
        let codexImage = try XCTUnwrap(codex.renderImage())
        let bothImage = try XCTUnwrap(both.renderImage())
        XCTAssertGreaterThan(bothImage.size.width, claudeImage.size.width + codexImage.size.width)
        XCTAssertEqual(bothImage.size.height, 18)
        XCTAssertTrue(bothImage.isTemplate)
        XCTAssertEqual(both.accessibilityText, "Claude 22% / Codex 0%")
        XCTAssertEqual(claude.accessibilityText, "Claude 22%")
        XCTAssertEqual(codex.accessibilityText, "Codex 0%")
    }

    @MainActor
    func testNoProvidersRenderFallback() throws {
        let content = MenuBarContent(claude: nil, codex: nil)
        XCTAssertEqual(content.accessibilityText, "LLM Limits")
        XCTAssertNotNil(content.renderImage())
    }
}
