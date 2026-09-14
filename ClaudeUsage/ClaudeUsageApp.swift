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
    let percent: Int
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

    var accessibilityText: String {
        let labels = entries.map { entry -> String in
            // 계정이 하나면 이름을 덧붙이지 않는다. 여러 개일 때만 누가 누군지 밝힌다.
            let body: String
            if entry.accounts.count == 1 {
                body = "\(entry.accounts[0].percent)%"
            } else {
                body = entry.accounts
                    .map { "\($0.label) \($0.percent)%" }
                    .joined(separator: " · ")
            }
            let overflow = entry.overflow > 0 ? " 외 \(entry.overflow)개" : ""
            return "\(entry.providerName) \(body)\(overflow)"
        }
        return labels.isEmpty ? "LLM Limits" : labels.joined(separator: " / ")
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
        HStack(spacing: 3) {
            if entry.provider == .claude {
                ProviderMark(provider: entry.provider)
            } else {
                Text(">_").font(.system(size: 10, weight: .heavy, design: .monospaced))
            }

            ForEach(Array(entry.accounts.enumerated()), id: \.offset) { index, account in
                if index > 0 {
                    Text("·").opacity(0.5)
                }
                Text("\(account.percent)%")
            }

            if entry.overflow > 0 {
                Text("+\(entry.overflow)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .opacity(0.7)
            }
        }
    }
}
