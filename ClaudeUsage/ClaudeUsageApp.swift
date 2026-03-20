import SwiftUI

@main
struct ClaudeUsageApp: App {
    @StateObject private var usageService = UsageService()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(service: usageService)
        } label: {
            MenuBarLabel(service: usageService)
        }
        .menuBarExtraStyle(.window)

        Window("Claude 설정", id: "settings") {
            SettingsView(service: usageService)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var service: UsageService

    private var utilization: Double {
        service.usage?.fiveHour?.utilization ?? 0
    }

    private var color: Color {
        if !service.isConfigured { return .gray }
        if utilization < 50 { return Color(red: 0.0, green: 0.55, blue: 0.35) }
        if utilization < 80 { return Color(red: 0.8, green: 0.5, blue: 0.0) }
        return Color(red: 0.8, green: 0.15, blue: 0.15)
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "sparkle")
            if service.isConfigured {
                Text("\(Int(utilization))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
        .foregroundStyle(color)
        .onAppear {
            if service.isConfigured {
                service.startPolling()
            }
        }
    }
}
