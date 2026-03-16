import Foundation
import SwiftUI

@MainActor
final class UsageService: ObservableObject {
    @Published var usage: UsageData?
    @Published var isLoading = false
    @Published var error: String?

    private var timer: Timer?
    private let refreshInterval: TimeInterval = 300

    var sessionCookie: String {
        get { KeychainService.load(key: "sessionCookie") ?? "" }
        set { _ = KeychainService.save(key: "sessionCookie", value: newValue) }
    }

    var organizationId: String {
        get { KeychainService.load(key: "organizationId") ?? "" }
        set { _ = KeychainService.save(key: "organizationId", value: newValue) }
    }

    var isConfigured: Bool {
        !sessionCookie.isEmpty && !organizationId.isEmpty
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
        guard isConfigured else {
            error = "쿠키 또는 조직 ID가 설정되지 않았습니다"
            return
        }

        isLoading = true
        error = nil

        let urlString = "https://claude.ai/api/organizations/\(organizationId)/usage"
        guard let url = URL(string: urlString) else {
            error = "잘못된 URL"
            isLoading = false
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
                    self.isLoading = false
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    self.error = "HTTP \(httpResponse.statusCode) - 쿠키가 만료되었을 수 있습니다"
                    self.isLoading = false
                    return
                }

                let decoded = try JSONDecoder().decode(UsageData.self, from: data)
                self.usage = decoded
                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
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
