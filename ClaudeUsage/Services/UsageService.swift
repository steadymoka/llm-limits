import Foundation
import SwiftUI

@MainActor
final class UsageService: ObservableObject {
    @Published var usage: UsageData?
    @Published var error: String?
    @Published private(set) var codexUsage: CodexUsageData?
    @Published private(set) var codexError: String?
    @Published private(set) var isClaudeLoading = false
    @Published private(set) var isCodexLoading = false
    @Published private(set) var isCodexInstalled = false
    @Published private(set) var hasCheckedCodex = false

    private var timer: Timer?
    private let refreshInterval: TimeInterval = 300

    private var _sessionCookie: String
    private var _organizationId: String

    var sessionCookie: String {
        get { _sessionCookie }
        set {
            _sessionCookie = newValue
            saveCredentials()
        }
    }

    var organizationId: String {
        get { _organizationId }
        set {
            _organizationId = newValue
            saveCredentials()
        }
    }

    var isConfigured: Bool {
        !_sessionCookie.isEmpty && !_organizationId.isEmpty
    }

    var isLoading: Bool {
        isClaudeLoading || isCodexLoading
    }

    var menuBarUtilization: Double? {
        [usage?.fiveHour?.utilization, codexUsage?.representativeUtilization]
            .compactMap { $0 }
            .max()
    }

    var activeProviderCount: Int {
        [usage != nil, codexUsage != nil].filter { $0 }.count
    }

    private static let credentialsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("llm-limits")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".credentials")
    }()

    private static let legacyCredentialsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("cc-usage/.credentials")
    }()

    init() {
        let creds = Self.loadCredentials()
        _sessionCookie = creds.cookie
        _organizationId = creds.orgId
    }

    private func saveCredentials() {
        let data = "\(_sessionCookie)\n\(_organizationId)"
        try? data.write(to: Self.credentialsURL, atomically: true, encoding: .utf8)
    }

    private static func loadCredentials() -> (cookie: String, orgId: String) {
        let sourceURL = FileManager.default.fileExists(atPath: credentialsURL.path)
            ? credentialsURL
            : legacyCredentialsURL
        guard let raw = try? String(contentsOf: sourceURL, encoding: .utf8) else {
            return ("", "")
        }
        if sourceURL == legacyCredentialsURL {
            try? raw.write(to: credentialsURL, atomically: true, encoding: .utf8)
        }
        let parts = raw.split(separator: "\n", maxSplits: 1).map(String.init)
        return (parts.first ?? "", parts.count > 1 ? parts[1] : "")
    }

    func startPolling() {
        fetchUsage()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchUsage()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func fetchUsage() {
        fetchClaudeUsage()
        fetchCodexUsage()
    }

    private func fetchClaudeUsage() {
        guard isConfigured else {
            usage = nil
            error = nil
            isClaudeLoading = false
            return
        }
        guard !isClaudeLoading else { return }

        isClaudeLoading = true
        error = nil

        let urlString = "https://claude.ai/api/organizations/\(organizationId)/usage"
        guard let url = URL(string: urlString) else {
            error = "잘못된 URL"
            isClaudeLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)",
            forHTTPHeaderField: "User-Agent"
        )

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.error = "응답 오류"
                    self.isClaudeLoading = false
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    self.error = "HTTP \(httpResponse.statusCode) - 쿠키가 만료되었을 수 있습니다"
                    self.isClaudeLoading = false
                    return
                }

                let decoded = try JSONDecoder().decode(UsageData.self, from: data)
                self.usage = decoded
                self.isClaudeLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isClaudeLoading = false
            }
        }
    }

    private func fetchCodexUsage() {
        guard !isCodexLoading else { return }
        guard let executableURL = CodexUsageClient.executableURL() else {
            isCodexInstalled = false
            hasCheckedCodex = true
            codexUsage = nil
            codexError = nil
            return
        }

        isCodexInstalled = true
        isCodexLoading = true
        codexError = nil

        Task {
            do {
                codexUsage = try await CodexUsageClient.fetchUsage(using: executableURL)
            } catch is CancellationError {
                // A later refresh or app shutdown can cancel this request.
            } catch {
                codexError = error.localizedDescription
            }
            isCodexLoading = false
            hasCheckedCodex = true
        }
    }

    func fetchOrganizationId() async -> String? {
        guard !sessionCookie.isEmpty else { return nil }

        // 쿠키에서 lastActiveOrg 추출 시도
        let parts = sessionCookie.components(separatedBy: ";")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("lastActiveOrg=") {
                let orgId = trimmed.replacingOccurrences(of: "lastActiveOrg=", with: "")
                if !orgId.isEmpty { return orgId }
            }
        }

        // Bootstrap API fallback
        guard let url = URL(string: "https://claude.ai/api/bootstrap") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let account = json["account"] as? [String: Any],
               let orgId = account["lastActiveOrgId"] as? String {
                return orgId
            }
        } catch {}

        return nil
    }
}
