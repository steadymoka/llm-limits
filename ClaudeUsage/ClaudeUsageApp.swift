import SwiftUI

@main
struct LLMLimitsApp: App {
    @StateObject private var usageService = UsageService()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(service: usageService)
        } label: {
            MenuBarLabel(service: usageService)
        }
        .menuBarExtraStyle(.window)

        Window("LLM Limits 설정", id: "settings") {
            SettingsView(service: usageService)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var service: UsageService

    var body: some View {
        let content = MenuBarContent(entries: service.menuBarEntries)
        Group {
            if let image = content.renderImage() {
                Image(nsImage: image)
            } else {
                Text(content.accessibilityText)
            }
        }
        .accessibilityLabel(content.accessibilityText)
        .help(content.accessibilityText)
        .onAppear { service.startPolling() }
    }
}

struct MenuBarAccount: Equatable {
    let label: String
    /// 창 순서대로 든 막대. 그 계정에 없는 창은 빠져 있다.
    let bars: [MenuBarBar]

    /// 툴팁·접근성에서 읽어줄 "5시간 35% · 주간 62% · Fable 88%".
    var summary: String {
        bars.map { "\($0.name) \($0.percent)%" }.joined(separator: " · ")
    }
}

/// 한 제공자의 메뉴바 표시분. 활성 계정이 항상 맨 앞이고,
/// 계정이 많아도 메뉴바가 무한정 넓어지지 않게 인라인 개수를 제한한다.
struct MenuBarEntry: Equatable {
    static let inlineLimit = 3

    let provider: UsageProvider
    let accounts: [MenuBarAccount]
    let overflow: Int

    init(provider: UsageProvider, accounts: [MenuBarAccount], overflow: Int = 0) {
        self.provider = provider
        self.accounts = accounts
        self.overflow = overflow
    }

    var providerName: String {
        switch provider {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }
}

// MenuBarExtra bridges its label to an NSStatusItem, not a normal SwiftUI
// layout. Flatten the whole label so every provider survives that bridge.
struct MenuBarContent: View {
    let entries: [MenuBarEntry]

    /// 막대는 어느 한도인지까지는 말해주지 못한다. 숫자와 이름은 여기서 갚는다.
    var accessibilityText: String {
        let labels = entries.map { entry -> String in
            // 계정이 하나면 이름을 덧붙이지 않는다. 여러 개일 때만 누가 누군지 밝힌다.
            let body: String
            if entry.accounts.count == 1 {
                body = entry.accounts[0].summary
            } else {
                body = entry.accounts
                    .map { "\($0.label) \($0.summary)" }
                    .joined(separator: " / ")
            }
            let overflow = entry.overflow > 0 ? " 외 \(entry.overflow)개" : ""
            return "\(entry.providerName) \(body)\(overflow)"
        }
        // 제공자끼리는 줄을 바꾼다. 한 줄에 몰면 어디까지가 Claude인지 흐려진다.
        return labels.isEmpty ? "LLM Limits" : labels.joined(separator: "\n")
    }

    @MainActor
    func renderImage() -> NSImage? {
        let renderer = ImageRenderer(content: self.environment(\.colorScheme, .light))
        renderer.scale = 3
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                if index > 0 {
                    Text("/")
                }
                indicator(for: entry)
            }
            if entries.isEmpty {
                Image(systemName: "terminal.fill")
            }
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.black)
        .frame(height: 18)
        .fixedSize()
    }

    private func indicator(for entry: MenuBarEntry) -> some View {
        HStack(spacing: 4) {
            ProviderMark(provider: entry.provider)

            ForEach(Array(entry.accounts.enumerated()), id: \.offset) { _, account in
                MenuBarBars(bars: account.bars)
            }

            if entry.overflow > 0 {
                Text("+\(entry.overflow)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .opacity(0.7)
            }
        }
    }
}

/// 계정 하나를 막대 세 줄로 그린다. 줄 위치가 창을 뜻하므로
/// 값이 없는 창도 빈 트랙을 남긴다. Codex의 빈 셋째 줄은
/// "여기엔 모델별 주간 한도가 없다"는 뜻이다.
struct MenuBarBars: View {
    static let width: CGFloat = 18
    static let thickness: CGFloat = 3

    let bars: [MenuBarBar]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(MenuBarWindow.allCases, id: \.self) { window in
                let bar = bars.first { $0.window == window }
                ZStack(alignment: .leading) {
                    // 템플릿 이미지라 색은 남지 않는다. 트랙과 채움은 진하기로만 갈린다.
                    track.opacity(bar == nil ? 0.13 : 0.26)
                    if let bar {
                        track.frame(width: max(1, Self.width * bar.fill))
                    }
                }
                .frame(width: Self.width, height: Self.thickness)
            }
        }
    }

    private var track: some View {
        RoundedRectangle(cornerRadius: 1).fill(.black)
    }
}
