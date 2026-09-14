import XCTest
@testable import LLMLimits

final class CredentialsStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("llm-limits-credentials-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var fileURL: URL { directory.appendingPathComponent(".credentials") }
    private var legacyURL: URL { directory.appendingPathComponent("legacy-credentials") }

    func testMigratesTheSingleAccountFormatWithoutLosingTheCookie() throws {
        try Data("sessionKey=abc; lastActiveOrg=org-a\norg-a".utf8).write(to: legacyURL)

        let loaded = CredentialsStore.load(from: fileURL, legacy: legacyURL)

        XCTAssertEqual(loaded, [ClaudeCredential(orgId: "org-a", cookie: "sessionKey=abc; lastActiveOrg=org-a", label: nil)])
        // 승격된 파일에서 다시 읽어도 같아야 한다.
        XCTAssertEqual(CredentialsStore.load(from: fileURL, legacy: legacyURL), loaded)
    }

    func testStoresSeveralAccountsAndKeepsTheFilePrivate() throws {
        let credentials = [
            ClaudeCredential(orgId: "org-a", cookie: "cookie-a", label: "first@example.com"),
            ClaudeCredential(orgId: "org-b", cookie: "cookie-b", label: "second@example.com"),
        ]

        CredentialsStore.save(credentials, to: fileURL)

        XCTAssertEqual(CredentialsStore.load(from: fileURL, legacy: legacyURL), credentials)

        let permissions = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: fileURL.path)[.posixPermissions] as? NSNumber
        )
        XCTAssertEqual(permissions.int16Value, 0o600, "세션 쿠키 파일이 다른 사용자에게 읽히면 안 된다")
    }

    func testIgnoresIncompleteEntries() throws {
        CredentialsStore.save(
            [
                ClaudeCredential(orgId: "org-a", cookie: "cookie-a", label: nil),
                ClaudeCredential(orgId: "", cookie: "orphan", label: nil),
                ClaudeCredential(orgId: "org-c", cookie: "", label: nil),
            ],
            to: fileURL
        )

        XCTAssertEqual(CredentialsStore.load(from: fileURL, legacy: legacyURL).map(\.orgId), ["org-a"])
    }

    func testReturnsNothingWhenNoFileExists() {
        XCTAssertTrue(CredentialsStore.load(from: fileURL, legacy: legacyURL).isEmpty)
    }
}

extension CredentialsStoreTests {
    func testKeepsACookieThatWasStoredWithoutAnOrganizationId() throws {
        // 조직 id를 저장하지 못한 채 쿠키만 남은 설정 파일이 실제로 존재한다.
        try Data("sessionKey=abc; lastActiveOrg=org-a".utf8).write(to: fileURL)

        XCTAssertTrue(CredentialsStore.load(from: fileURL, legacy: legacyURL).isEmpty)
        XCTAssertEqual(
            CredentialsStore.pendingCookie(from: fileURL, legacy: legacyURL),
            "sessionKey=abc; lastActiveOrg=org-a"
        )
    }

    func testNoPendingCookieOnceTheFileIsUpgraded() throws {
        CredentialsStore.save([ClaudeCredential(orgId: "org-a", cookie: "cookie-a", label: nil)], to: fileURL)

        XCTAssertNil(CredentialsStore.pendingCookie(from: fileURL, legacy: legacyURL))
    }

    func testNoPendingCookieForTheTwoLineFormat() throws {
        try Data("cookie-a\norg-a".utf8).write(to: legacyURL)

        XCTAssertNil(CredentialsStore.pendingCookie(from: fileURL, legacy: legacyURL))
    }
}
