import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var service: UsageService
    @Environment(\.openWindow) private var openWindow

    private var showsClaude: Bool {
        service.isConfigured || service.usage != nil
    }

    private var showsCodex: Bool {
        service.isCodexInstalled || service.codexUsage != nil
    }

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

            Text("LOCAL")
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.1), in: Capsule())

            Spacer(minLength: 8)

            RefreshButton(isLoading: service.isLoading) {
                service.fetchUsage()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !showsClaude && !showsCodex && !service.hasCheckedCodex {
            loadingView
                .padding(.vertical, 18)
        } else if !showsClaude && !showsCodex {
            emptyView
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
        } else {
            VStack(spacing: 0) {
                if showsClaude {
                    claudeSection
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                }

                if showsClaude && showsCodex {
                    Divider()
                        .padding(.horizontal, 12)
                        .opacity(0.55)
                }

                if showsCodex {
                    codexSection
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                }
            }
        }
    }

    private var claudeSection: some View {
        providerSection(
            name: "CLAUDE",
            provider: .claude,
            badge: nil,
            statusColor: providerStatusColor(dataAvailable: service.usage != nil, error: service.error)
        ) {
            if let usage = service.usage {
                VStack(spacing: 7) {
                    UsageRowView(title: "5시간 세션", metric: usage.fiveHour)
                    UsageRowView(title: "주간 · 전체", metric: usage.sevenDay)
                    if let sonnet = usage.sevenDaySonnet {
                        UsageRowView(title: "주간 · Sonnet", metric: sonnet)
                    }
                    if let design = usage.sevenDayOmelette {
                        UsageRowView(title: "주간 · Claude Design", metric: design)
                    }
                    ForEach(usage.modelScopedWeeklyLimits, id: \.self) { limit in
                        UsageRowView(
                            title: "주간 · \(limit.scope?.model?.displayName ?? "모델")",
                            metric: limit.asMetric
                        )
                    }
                }

                if let error = service.error {
                    InlineStatus(message: error, color: .red)
                        .padding(.top, 2)
                }
            } else if service.isClaudeLoading {
                inlineLoading
            } else if let error = service.error {
                InlineStatus(message: error, color: .red)
            }
        }
    }

    private var codexSection: some View {
        providerSection(
            name: "CODEX",
            provider: .codex,
            badge: service.codexUsage?.planLabel,
            statusColor: providerStatusColor(dataAvailable: service.codexUsage != nil, error: service.codexError)
        ) {
            if let usage = service.codexUsage {
                if usage.displayLimits.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: usage.isUnlimited ? "infinity" : "minus")
                        Text(usage.isUnlimited ? "UNLIMITED" : "한도 정보 없음")
                        Spacer()
                    }
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 7) {
                        ForEach(usage.displayLimits) { limit in
                            UsageRowView(title: limit.title, metric: limit.metric)
                        }
                    }
                }

                if let error = service.codexError {
                    InlineStatus(message: error, color: .red)
                        .padding(.top, 2)
                }
            } else if service.isCodexLoading {
                inlineLoading
            } else if let error = service.codexError {
                InlineStatus(message: error, color: .red)
            }
        }
    }

    private func providerSection<Content: View>(
        name: String,
        provider: UsageProvider,
        badge: String?,
        statusColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                ProviderMark(provider: provider)

                Text(name)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(0.7)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
            }

            content()
        }
    }

    private func providerStatusColor(dataAvailable: Bool, error: String?) -> Color {
        if error != nil { return .red }
        if dataAvailable { return Color(red: 0.1, green: 0.68, blue: 0.43) }
        return .secondary.opacity(0.55)
    }

    private var loadingView: some View {
        HStack(spacing: 7) {
            ProgressView()
                .controlSize(.mini)
            Text("로컬 사용량 소스 확인 중")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var inlineLoading: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
            Text("SYNCING")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
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

            Text("Claude 쿠키를 설정하거나 Codex에 로그인하세요")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

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
        let count = service.activeProviderCount
        let source = count == 1 ? "1 SOURCE" : "\(count) SOURCES"
        return "\(source) · AUTO 5M"
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

enum UsageProvider {
    case claude
    case codex
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

private struct InlineStatus: View {
    let message: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(color)
                .padding(.top, 1)
            Text(message)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

private struct RefreshButton: View {
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
