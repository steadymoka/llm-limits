import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var service: UsageService
    @Environment(\.openWindow) private var openWindow

    /// 계정이 3개 이상일 때만 접기를 쓴다. 여기엔 사용자가 직접 펼친 계정만 담긴다.
    @State private var manuallyExpanded = Set<String>()

    /// 리셋 열의 표시 형식. 메뉴바 패널은 key window가 아니라 툴팁이 뜨지 않으므로,
    /// 절대시각은 숨기지 말고 이 전환으로 화면 안에서 보여준다.
    @AppStorage("showsAbsoluteReset") private var showsAbsoluteReset = true

    private static let collapseThreshold = 3

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

            Divider().opacity(0.7)
            content
            Divider().opacity(0.7)

            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(width: 284)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("LLM Limits")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))

            Spacer(minLength: 8)

            Button { showsAbsoluteReset.toggle() } label: {
                Image(systemName: showsAbsoluteReset ? "clock" : "clock.arrow.circlepath")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 15, height: 15)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(showsAbsoluteReset ? "남은 시간으로 보기" : "리셋 시각으로 보기")

            RefreshButton(isLoading: service.isLoading) {
                service.fetchUsage()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let claude = service.claudeAccounts
        let codex = service.codexAccounts

        if claude.isEmpty && codex.isEmpty {
            if service.hasCheckedSources {
                emptyView
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
            } else {
                loadingView
                    .padding(.vertical, 18)
            }
        } else {
            VStack(spacing: 0) {
                if !claude.isEmpty {
                    providerSection(name: "CLAUDE", provider: .claude, accounts: claude) {
                        if let notice = orcaNotice {
                            InlineStatus(message: notice, color: .orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }

                if !claude.isEmpty && !codex.isEmpty {
                    Divider()
                        .padding(.horizontal, 12)
                        .opacity(0.55)
                }

                if !codex.isEmpty {
                    providerSection(name: "CODEX", provider: .codex, accounts: codex) { EmptyView() }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
            }
        }
    }

    /// Orca를 아예 못 읽어 계정 목록이 비어 있을 때만 알린다.
    /// 스냅샷이 남아 있으면 계정별 나이 배지가 이미 사정을 말해준다.
    private var orcaNotice: String? {
        guard service.orcaSnapshot == nil, case .unavailable(let message) = service.orcaStatus else {
            return nil
        }
        return message
    }

    private func providerSection<Footer: View>(
        name: String,
        provider: UsageProvider,
        accounts: [AccountCard],
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        let isCollapsible = accounts.count >= Self.collapseThreshold

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ProviderMark(provider: provider)

                Text(name)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(0.7)

                Spacer()

                if accounts.count > 1 {
                    Text("\(accounts.count) ACCOUNTS")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Circle()
                    .fill(statusColor(for: accounts))
                    .frame(width: 5, height: 5)
            }

            ForEach(Array(accounts.enumerated()), id: \.element.id) { index, card in
                if index > 0 {
                    Divider().opacity(0.4)
                }
                AccountSectionView(
                    card: card,
                    showsActiveBadge: accounts.count > 1,
                    isExpanded: isExpanded(card, isCollapsible: isCollapsible),
                    isCollapsible: isCollapsible,
                    showsAbsoluteReset: showsAbsoluteReset,
                    onToggleResetFormat: { showsAbsoluteReset.toggle() },
                    onToggle: { toggle(card) }
                )
            }

            footer()
        }
    }

    private func isExpanded(_ card: AccountCard, isCollapsible: Bool) -> Bool {
        guard isCollapsible else { return true }
        return card.isActive || manuallyExpanded.contains(card.key.storageID)
    }

    private func toggle(_ card: AccountCard) {
        let id = card.key.storageID
        if manuallyExpanded.contains(id) {
            manuallyExpanded.remove(id)
        } else {
            manuallyExpanded.insert(id)
        }
    }

    private func statusColor(for accounts: [AccountCard]) -> Color {
        if accounts.contains(where: { !$0.rows.isEmpty }) {
            return Color(red: 0.1, green: 0.68, blue: 0.43)
        }
        if accounts.contains(where: { $0.error != nil }) { return .red }
        return .secondary.opacity(0.55)
    }

    private var loadingView: some View {
        HStack(spacing: 7) {
            ProgressView()
                .controlSize(.mini)
            Text("사용량 소스 확인 중")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(.secondary)

            Text("NO USAGE SOURCE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            Text("Orca에 계정을 추가하거나, Claude 쿠키를 설정하거나, Codex에 로그인하세요")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("OPEN CONFIG") { openSettings() }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { openSettings() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 15, height: 15)
            }
            .buttonStyle(.plain)
            .help("설정")

            Spacer()

            Text(footerStatus)
                .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(0.4)

            Spacer()

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 15, height: 15)
            }
            .buttonStyle(.plain)
            .help("종료")
        }
    }

    private var footerStatus: String {
        let count = service.activeAccountCount
        let accounts = count == 1 ? "1 ACCOUNT" : "\(count) ACCOUNTS"
        return "\(accounts) · AUTO 5M"
    }

    private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        if let existing = NSApp.windows.first(where: { $0.title == "LLM Limits 설정" }) {
            existing.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "settings")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct ProviderMark: View {
    let provider: UsageProvider

    var body: some View {
        switch provider {
        case .claude:
            ClaudeMark()
        case .codex:
            CodexMark()
        }
    }
}

private struct ClaudeMark: View {
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .frame(width: 1.5, height: 11)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
        }
        .foregroundStyle(Color(red: 0.86, green: 0.38, blue: 0.18))
        .frame(width: 13, height: 13)
        .accessibilityLabel("Claude")
    }
}

private struct CodexMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(.primary)
            Text(">_")
                .font(.system(size: 5.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                .offset(y: -0.2)
        }
        .frame(width: 13, height: 13)
        .accessibilityLabel("Codex")
    }
}

struct RefreshButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 15, height: 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help("새로고침")
    }
}
