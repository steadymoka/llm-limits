import Foundation

struct ClaudeCredential: Codable, Equatable, Identifiable {
    var orgId: String
    var cookie: String
    var label: String?

    var id: String { orgId }
}

/// 계정이 여러 개가 되면서 한 줄짜리 `cookie\norgId` 포맷으로는 부족해
/// 버전이 붙은 JSON으로 옮긴다. 옛 포맷은 읽는 순간 조용히 승격된다.
enum CredentialsStore {
    private struct Payload: Codable {
        var version: Int
        var claude: [ClaudeCredential]
    }

    private static let currentVersion = 2

    static let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("llm-limits")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".credentials")
    }()

    private static let legacyFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("cc-usage/.credentials")
    }()

    static func load(from url: URL = fileURL, legacy: URL = legacyFileURL) -> [ClaudeCredential] {
        guard let data = read(from: url, legacy: legacy) else { return [] }

        if let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            return payload.claude.filter { !$0.orgId.isEmpty && !$0.cookie.isEmpty }
        }

        let parsed = parseLegacy(data)
        guard !parsed.cookie.isEmpty, !parsed.orgId.isEmpty else { return [] }

        let migrated = [ClaudeCredential(orgId: parsed.orgId, cookie: parsed.cookie, label: nil)]
        save(migrated, to: url)
        return migrated
    }

    static func save(_ credentials: [ClaudeCredential], to url: URL = fileURL) {
        let payload = Payload(version: currentVersion, claude: credentials)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        do {
            try data.write(to: url, options: .atomic)
            // 세션 쿠키는 비밀번호급이다. 원자적 쓰기가 새 inode를 만들므로 매번 다시 좁힌다.
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            return
        }
    }

    /// 조직 id 없이 쿠키만 저장된 v1 파일이 존재한다. 그런 쿠키는 버리지 말고
    /// 조직 id를 해석해 v2로 승격할 수 있도록 호출자에게 돌려준다.
    static func pendingCookie(from url: URL = fileURL, legacy: URL = legacyFileURL) -> String? {
        guard let data = read(from: url, legacy: legacy),
              (try? JSONDecoder().decode(Payload.self, from: data)) == nil else { return nil }
        let parsed = parseLegacy(data)
        guard parsed.orgId.isEmpty, !parsed.cookie.isEmpty else { return nil }
        return parsed.cookie
    }

    private static func read(from url: URL, legacy: URL) -> Data? {
        let fileManager = FileManager.default
        let sourceURL = fileManager.fileExists(atPath: url.path) ? url : legacy
        return try? Data(contentsOf: sourceURL)
    }

    /// v1: 첫 줄 쿠키, 둘째 줄 조직 id.
    private static func parseLegacy(_ data: Data) -> (cookie: String, orgId: String) {
        let raw = String(decoding: data, as: UTF8.self)
        let parts = raw.split(separator: "\n", maxSplits: 1).map(String.init)
        return (
            parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            (parts.count > 1 ? parts[1] : "").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
