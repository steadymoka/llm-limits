import SwiftUI

struct SettingsView: View {
    @ObservedObject var service: UsageService
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var cookieTarget: CookieTarget?
    @State private var statusMessage: StatusMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            titleBar

            Divider()

            claudeSection

            codexSection

            if let statusMessage {
                Text(statusMessage.text)
                    .font(.system(size: 11))
                    .foregroundStyle(statusMessage.color)
            }

            HStack {
                Spacer()
                Button("닫기") { closeSettings() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 404)
        .sheet(item: $cookieTarget) { target in
            CookieSheet(service: service, target: target) { message in
                statusMessage = message
                cookieTarget = nil
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private var titleBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("LLM Limits")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
            Spacer()
            Text("CONFIG")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(0.7)
        }
    }

    // MARK: - Claude

    private var claudeSection: some View {
        let accounts = service.claudeAccounts

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ProviderMark(provider: .claude)
                Text("CLAUDE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(0.7)
                Spacer()
                Text(orcaStatusText)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(orcaStatusColor)
            }

            if accounts.isEmpty {
                Text("등록된 계정이 없습니다. Orca에 Claude 계정을 추가하거나(`orca account add`) 아래에서 세션 쿠키를 등록하세요.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 5) {
                    ForEach(accounts) { card in
                        accountRow(card)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Button("쿠키 추가") {
                    cookieTarget = CookieTarget(orgId: nil, label: nil)
                }
                .font(.system(size: 10))
                .controlSize(.small)

                Text("쿠키를 등록한 계정은 Orca 스냅샷 대신 항상 최신 값으로 표시되고, 응답에 있으면 Sonnet·Claude Design 한도까지 보여줍니다.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func accountRow(_ card: AccountCard) -> some View {
        let orgID = card.key.claudeOrgID
        let hasCookie = orgID.flatMap { service.credential(forOrgId: $0) } != nil

        return HStack(spacing: 6) {
            Image(systemName: card.isActive ? "circle.fill" : "circle")
                .font(.system(size: 6))
                .foregroundStyle(card.isActive ? Color.accentColor : Color.secondary.opacity(0.45))

            Text(card.label)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            if card.isActive {
                Text("ACTIVE")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
            }

            Spacer(minLength: 4)

            Text(hasCookie ? "COOKIE" : "ORCA")
                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(hasCookie ? Color(red: 0.1, green: 0.6, blue: 0.4) : Color.secondary.opacity(0.6))

            Button {
                service.setMenuBarVisibility(!service.isVisibleInMenuBar(card.key), for: card.key)
            } label: {
                Image(systemName: service.isVisibleInMenuBar(card.key) ? "eye" : "eye.slash")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(service.isVisibleInMenuBar(card.key) ? "메뉴바에서 숨기기" : "메뉴바에 표시")

            Button(hasCookie ? "갱신" : "쿠키") {
                cookieTarget = CookieTarget(orgId: orgID, label: card.label)
            }
            .font(.system(size: 9))
            .controlSize(.mini)

            if hasCookie, let orgID {
                Button {
                    service.removeCredential(orgId: orgID)
                    statusMessage = .init(text: "\(card.shortLabel) 쿠키를 삭제했습니다", kind: .neutral)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("쿠키 삭제")
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }

    private var orcaStatusText: String {
        switch service.orcaStatus {
        case .checking: return "CHECKING"
        case .notInstalled: return "ORCA NOT FOUND"
        case .unavailable: return "ORCA OFFLINE"
        case .ok:
            let count = service.orcaSnapshot?.claude.count ?? 0
            return count == 1 ? "ORCA · 1 ACCOUNT" : "ORCA · \(count) ACCOUNTS"
        }
    }

    private var orcaStatusColor: Color {
        switch service.orcaStatus {
        case .ok: return Color(red: 0.1, green: 0.6, blue: 0.4)
        case .unavailable: return .orange
        default: return .secondary.opacity(0.7)
        }
    }

    // MARK: - Codex

    private var codexSection: some View {
        HStack(alignment: .top, spacing: 8) {
            ProviderMark(provider: .codex)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("CODEX")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                    Text(codexStatus)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(codexStatusColor)
                }
                Text("설치된 Codex CLI의 ChatGPT 로그인을 자동으로 사용합니다. 별도 설정은 필요 없습니다.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }

    private var codexStatus: String {
        if service.isCodexLoading { return "SYNCING" }
        if service.codexUsage != nil { return "CONNECTED" }
        if service.codexError != nil { return "ERROR" }
        if service.isCodexInstalled { return "DETECTED" }
        return "NOT FOUND"
    }

    private var codexStatusColor: Color {
        if service.codexError != nil { return .red }
        if service.codexUsage != nil { return .green }
        return .secondary.opacity(0.7)
    }

    private func closeSettings() {
        NSApp.setActivationPolicy(.accessory)
        dismissWindow(id: "settings")
    }
}

// MARK: - 쿠키 입력

struct CookieTarget: Identifiable {
    /// nil이면 어느 계정이든 받는다(새 계정 추가).
    let orgId: String?
    let label: String?

    var id: String { orgId ?? "new" }
}

struct StatusMessage {
    enum Kind {
        case success
        case warning
        case failure
        case neutral
    }

    let text: String
    let kind: Kind

    var color: Color {
        switch kind {
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        case .neutral: return .secondary
        }
    }
}

private struct CookieSheet: View {
    @ObservedObject var service: UsageService
    let target: CookieTarget
    let onFinish: (StatusMessage?) -> Void

    @State private var cookieText = ""
    @State private var isSaving = false
    @State private var inlineMessage: StatusMessage?
    /// 다른 계정의 쿠키였을 때, 사용자가 그 계정에 붙이겠다고 하면 쓸 값.
    @State private var mismatchedCookie: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                ProviderMark(provider: .claude)
                Text(target.label ?? "Claude 계정 추가")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("SESSION COOKIE")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Text("브라우저 개발자도구(F12) → Network 탭 → claude.ai 요청 → Cookie 헤더 값을 복사하세요.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)

            TextField("쿠키 값을 붙여넣으세요", text: $cookieText, axis: .vertical)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(7)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.25)))
                .focused($isFocused)

            if let inlineMessage {
                Text(inlineMessage.text)
                    .font(.system(size: 10.5))
                    .foregroundStyle(inlineMessage.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let mismatchedCookie {
                    Button("해당 계정에 연결") {
                        save(cookie: mismatchedCookie, ignoringMismatch: true)
                    }
                    .font(.system(size: 10))
                    .controlSize(.small)
                }

                Spacer()

                Button("취소") { onFinish(nil) }
                Button("저장") { save(cookie: cookieText, ignoringMismatch: false) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(cookieText.isEmpty || isSaving)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            if let orgId = target.orgId, let existing = service.credential(forOrgId: orgId) {
                cookieText = existing.cookie
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isFocused = true }
        }
    }

    private func save(cookie: String, ignoringMismatch: Bool) {
        isSaving = true
        inlineMessage = .init(text: "계정 확인 중...", kind: .neutral)
        mismatchedCookie = nil

        Task {
            let outcome = ignoringMismatch
                ? await service.saveCookieIgnoringMismatch(cookie)
                : await service.saveCookie(cookie, expectedOrgId: target.orgId)

            switch outcome {
            case .saved(let orgId):
                onFinish(.init(text: "쿠키를 저장했습니다 (조직 \(orgId.prefix(8)))", kind: .success))
            case .mismatch(let resolved, let resolvedLabel):
                mismatchedCookie = cookie
                let who = resolvedLabel ?? String(resolved.prefix(8))
                inlineMessage = .init(
                    text: "이 쿠키는 \(who) 계정의 것입니다. 그 계정에 연결하려면 아래 버튼을 누르세요.",
                    kind: .warning
                )
            case .unresolved:
                inlineMessage = .init(text: "조직 ID를 가져올 수 없습니다. 쿠키를 확인하세요.", kind: .failure)
            }
            isSaving = false
        }
    }
}
