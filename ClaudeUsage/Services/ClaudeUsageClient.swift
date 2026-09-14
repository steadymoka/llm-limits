import Foundation

enum ClaudeUsageClientError: LocalizedError {
    case invalidURL
    case badResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL"
        case .badResponse:
            return "응답 오류"
        case .http(let code):
            if code == 401 || code == 403 {
                return "쿠키가 만료되었습니다 — 설정에서 다시 저장하세요"
            }
            return "HTTP \(code) - 쿠키가 만료되었을 수 있습니다"
        }
    }
}

struct ClaudeIdentity: Equatable {
    let orgId: String
    let email: String?
}

enum ClaudeUsageClient {
    static func fetchUsage(cookie: String, organizationId: String) async throws -> UsageData {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(organizationId)/usage") else {
            throw ClaudeUsageClientError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(for: request(url: url, cookie: cookie))

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeUsageClientError.badResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ClaudeUsageClientError.http(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(UsageData.self, from: data)
    }

    /// 쿠키가 어느 조직·계정의 것인지 알아낸다. 계정을 orgId로 합치기 때문에
    /// 저장 전에 반드시 해석해야 한다.
    static func resolveIdentity(cookie: String) async -> ClaudeIdentity? {
        guard !cookie.isEmpty else { return nil }

        var orgId = orgIdFromCookie(cookie)
        var email: String?

        if let url = URL(string: "https://claude.ai/api/bootstrap"),
           let (data, _) = try? await URLSession.shared.data(for: request(url: url, cookie: cookie)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let account = json["account"] as? [String: Any] {
            orgId = (account["lastActiveOrgId"] as? String) ?? orgId
            email = (account["email_address"] as? String) ?? (account["email"] as? String)
        }

        guard let orgId, !orgId.isEmpty else { return nil }
        return ClaudeIdentity(orgId: orgId, email: email)
    }

    private static func orgIdFromCookie(_ cookie: String) -> String? {
        for part in cookie.components(separatedBy: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("lastActiveOrg=") else { continue }
            let orgId = String(trimmed.dropFirst("lastActiveOrg=".count))
            if !orgId.isEmpty { return orgId }
        }
        return nil
    }

    private static func request(url: URL, cookie: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)",
            forHTTPHeaderField: "User-Agent"
        )
        return request
    }
}
