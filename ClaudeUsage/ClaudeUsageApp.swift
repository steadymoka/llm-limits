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
        let content = MenuBarContent(
            claude: service.claudeMenuBarUtilization,
            codex: service.codexMenuBarUtilization
        )
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

// MenuBarExtra bridges its label to an NSStatusItem, not a normal SwiftUI
// layout. Flatten the whole label so every provider survives that bridge.
struct MenuBarContent: View {
    let claude: Double?
    let codex: Double?

    var accessibilityText: String {
        let labels = [claude.map { "Claude \(Int($0.rounded()))%" },
         codex.map { "Codex \(Int($0.rounded()))%" }]
            .compactMap { $0 }.joined(separator: " / ")
        return labels.isEmpty ? "LLM Limits" : labels
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
            if let claude {
                indicator(.claude, utilization: claude)
            }
            if claude != nil && codex != nil {
                Text("/")
            }
            if let codex {
                indicator(.codex, utilization: codex)
            }
            if claude == nil && codex == nil {
                Image(systemName: "terminal.fill")
            }
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.black)
        .frame(height: 18)
        .fixedSize()
    }

    private func indicator(_ provider: UsageProvider, utilization: Double) -> some View {
        HStack(spacing: 3) {
            if provider == .claude {
                ProviderMark(provider: provider)
            } else {
                Text(">_").font(.system(size: 10, weight: .heavy, design: .monospaced))
            }
            Text("\(Int(utilization.rounded()))%")
        }
    }
}
