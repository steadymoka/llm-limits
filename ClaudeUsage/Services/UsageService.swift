import Foundation
import SwiftUI

enum OrcaStatus: Equatable {
    case checking
    case notInstalled
    case unavailable(String)
    case ok
}

enum CookieSaveOutcome: Equatable {
    case saved(orgId: String)
    /// 쿠키가 기대한 계정이 아닐 때. 사용자가 실제 계정에 붙일지 결정한다.
    case mismatch(resolved: String, resolvedLabel: String?)
    case unresolved
}

@MainActor
final class UsageService: ObservableObject {
    @Published private(set) var credentials: [ClaudeCredential]
    @Published private(set) var cookieStates: [String: AccountRegistry.CookieState] = [:]

    @Published private(set) var orcaSnapshot: OrcaSnapshot?
    @Published private(set) var orcaStatus: OrcaStatus = .checking
    @Published private(set) var isOrcaLoading = false

    @Published private(set) var codexUsage: CodexUsageData?
    @Published private(set) var codexError: String?
    @Published private(set) var codexFetchedAt: Date?
    @Published private(set) var isCodexLoading = false
    @Published private(set) var isCodexInstalled = false
    @Published private(set) var hasCheckedCodex = false

    @Published var hiddenMenuBarAccounts: Set<String> {
        didSet { Self.persistHidden(hiddenMenuBarAccounts) }
    }

    private var timer: Timer?
    private let refreshInterval: TimeInterval = 300
    private static let hiddenAccountsKey = "hiddenMenuBarAccounts"

    convenience init() {
        self.init(loadsStoredCredentials: true)
    }

    /// 저장된 자격증명을 읽지 않는 인스턴스를 만들 수 있어야 한다.
    /// 렌더 테스트가 사용자의 실제 설정 파일을 읽거나 옮겨 쓰면 안 된다.
    init(loadsStoredCredentials: Bool) {
        credentials = loadsStoredCredentials ? CredentialsStore.load() : []
        hiddenMenuBarAccounts = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenAccountsKey) ?? [])
        if loadsStoredCredentials {
            adoptPendingCookie()
        }
    }

    /// 조직 id 없이 쿠키만 저장돼 있던 설정은 그대로는 쓸 수 없다.
    /// 조직 id를 해석해 계정에 붙이고 v2로 옮긴다.
    private func adoptPendingCookie() {
        guard credentials.isEmpty, let cookie = CredentialsStore.pendingCookie() else { return }
        Task { _ = await saveCookie(cookie) }
    }

    // MARK: - 표시 모델

    var claudeAccounts: [AccountCard] {
        AccountRegistry.claudeCards(
            credentials: credentials,
            cookieStates: cookieStates,
            orca: orcaSnapshot
        )
    }

    var codexAccounts: [AccountCard] {
        AccountRegistry.codexCards(
            usage: codexUsage,
            error: codexError,
            fetchedAt: codexFetchedAt,
            isLoading: isCodexLoading,
            isInstalled: isCodexInstalled,
            orcaLabel: orcaSnapshot?.codexSystemDefaultLabel
        )
    }

    var menuBarEntries: [MenuBarEntry] {
        [
            menuBarEntry(for: .claude, cards: claudeAccounts),
            menuBarEntry(for: .codex, cards: codexAccounts),
        ].compactMap { $0 }
    }

    var isLoading: Bool {
        isOrcaLoading || isCodexLoading || cookieStates.values.contains { $0.isLoading }
    }

    /// 아직 어떤 소스도 확인하지 못한 최초 구동 순간.
    var hasCheckedSources: Bool {
        hasCheckedCodex && orcaStatus != .checking
    }

    var activeAccountCount: Int {
        (claudeAccounts + codexAccounts).filter { !$0.rows.isEmpty }.count
    }

    private func menuBarEntry(for provider: UsageProvider, cards: [AccountCard]) -> MenuBarEntry? {
        let accounts = cards
            .filter { !hiddenMenuBarAccounts.contains($0.key.storageID) }
            .compactMap { card -> MenuBarAccount? in
                guard let utilization = card.menuBarUtilization else { return nil }
                return MenuBarAccount(label: card.shortLabel, percent: Int(utilization.rounded()))
            }
        guard !accounts.isEmpty else { return nil }

        let shown = Array(accounts.prefix(MenuBarEntry.inlineLimit))
        return MenuBarEntry(
            provider: provider,
            accounts: shown,
            overflow: accounts.count - shown.count
        )
    }

    // MARK: - 폴링

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
        fetchOrcaSnapshot()
        fetchCookieUsage()
        fetchCodexUsage()
    }

    // MARK: - Orca

    private func fetchOrcaSnapshot() {
        guard !isOrcaLoading else { return }
        guard let executableURL = OrcaAccountsClient.executableURL() else {
            orcaSnapshot = nil
            orcaStatus = .notInstalled
            return
        }

        isOrcaLoading = true
        Task {
            do {
                orcaSnapshot = try await OrcaAccountsClient.fetchSnapshot(using: executableURL)
                orcaStatus = .ok
            } catch is CancellationError {
                // 다음 갱신이나 앱 종료가 이 호출을 취소할 수 있다.
            } catch {
                // 스냅샷을 버리지 않는다. Orca를 닫아도 마지막으로 본 값은 남는다.
                orcaStatus = .unavailable(error.localizedDescription)
            }
            isOrcaLoading = false
        }
    }

    // MARK: - Claude 쿠키

    private func fetchCookieUsage() {
        for credential in credentials {
            fetchCookieUsage(for: credential)
        }
    }

    private func fetchCookieUsage(for credential: ClaudeCredential) {
        let orgId = credential.orgId
        var state = cookieStates[orgId] ?? AccountRegistry.CookieState()
        guard !state.isLoading else { return }

        state.isLoading = true
        state.error = nil
        cookieStates[orgId] = state

        Task {
            var usage: UsageData?
            var failure: String?
            do {
                usage = try await ClaudeUsageClient.fetchUsage(
                    cookie: credential.cookie,
                    organizationId: orgId
                )
            } catch is CancellationError {
                // 무시: 다음 폴링이 다시 시도한다.
            } catch {
                failure = error.localizedDescription
            }

            // 기다리는 동안 쿠키가 바뀌었을 수 있으니 최신 상태 위에 결과를 얹는다.
            var next = cookieStates[orgId] ?? AccountRegistry.CookieState()
            if let usage {
                next.usage = usage
                next.fetchedAt = .now
                next.error = nil
            }
            next.error = failure ?? next.error
            next.isLoading = false
            cookieStates[orgId] = next
        }
    }

    // MARK: - Codex

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
                codexFetchedAt = .now
            } catch is CancellationError {
                // A later refresh or app shutdown can cancel this request.
            } catch {
                codexError = error.localizedDescription
            }
            isCodexLoading = false
            hasCheckedCodex = true
        }
    }

    // MARK: - 자격증명 편집

    /// 쿠키를 저장한다. `expectedOrgId`를 주면 그 계정의 쿠키인지 확인하고,
    /// 다른 계정의 것이면 저장하지 않고 알려준다.
    func saveCookie(_ cookie: String, expectedOrgId: String? = nil) async -> CookieSaveOutcome {
        let trimmed = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let identity = await ClaudeUsageClient.resolveIdentity(cookie: trimmed) else {
            return .unresolved
        }

        if let expectedOrgId, expectedOrgId != identity.orgId {
            return .mismatch(resolved: identity.orgId, resolvedLabel: identity.email)
        }

        store(cookie: trimmed, identity: identity)
        return .saved(orgId: identity.orgId)
    }

    /// 불일치 경고를 본 뒤 사용자가 실제 계정에 붙이기로 한 경우.
    func saveCookieIgnoringMismatch(_ cookie: String) async -> CookieSaveOutcome {
        await saveCookie(cookie)
    }

    private func store(cookie: String, identity: ClaudeIdentity) {
        let credential = ClaudeCredential(orgId: identity.orgId, cookie: cookie, label: identity.email)
        if let index = credentials.firstIndex(where: { $0.orgId == identity.orgId }) {
            credentials[index] = credential
        } else {
            credentials.append(credential)
        }
        CredentialsStore.save(credentials)
        cookieStates[identity.orgId] = AccountRegistry.CookieState()
        fetchCookieUsage(for: credential)
    }

    func removeCredential(orgId: String) {
        credentials.removeAll { $0.orgId == orgId }
        cookieStates[orgId] = nil
        CredentialsStore.save(credentials)
    }

    func credential(forOrgId orgId: String) -> ClaudeCredential? {
        credentials.first { $0.orgId == orgId }
    }

    func setMenuBarVisibility(_ isVisible: Bool, for key: AccountKey) {
        if isVisible {
            hiddenMenuBarAccounts.remove(key.storageID)
        } else {
            hiddenMenuBarAccounts.insert(key.storageID)
        }
    }

    func isVisibleInMenuBar(_ key: AccountKey) -> Bool {
        !hiddenMenuBarAccounts.contains(key.storageID)
    }

    private static func persistHidden(_ keys: Set<String>) {
        UserDefaults.standard.set(Array(keys), forKey: hiddenAccountsKey)
    }
}

#if DEBUG
extension UsageService {
    /// 프리뷰·렌더 테스트용 시드. private(set) 프로퍼티는 같은 파일에서만
    /// 설정할 수 있어 이 확장이 여기 있어야 한다.
    static func seeded(
        orca: OrcaSnapshot? = nil,
        orcaStatus: OrcaStatus = .ok,
        credentials: [ClaudeCredential] = [],
        cookieStates: [String: AccountRegistry.CookieState] = [:],
        codexUsage: CodexUsageData? = nil,
        codexError: String? = nil,
        isCodexInstalled: Bool = false
    ) -> UsageService {
        let service = UsageService(loadsStoredCredentials: false)
        service.orcaSnapshot = orca
        service.orcaStatus = orcaStatus
        service.credentials = credentials
        service.cookieStates = cookieStates
        service.codexUsage = codexUsage
        service.codexError = codexError
        service.codexFetchedAt = codexUsage == nil ? nil : .now
        service.isCodexInstalled = isCodexInstalled
        service.hasCheckedCodex = true
        return service
    }
}
#endif
