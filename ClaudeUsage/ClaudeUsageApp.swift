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

    private var utilization: Double {
        service.menuBarUtilization ?? 0
    }

    private var color: Color {
        guard service.menuBarUtilization != nil else { return .gray }
        if utilization < 50 { return Color(red: 0.0, green: 0.55, blue: 0.35) }
        if utilization < 80 { return Color(red: 0.8, green: 0.5, blue: 0.0) }
        return Color(red: 0.8, green: 0.15, blue: 0.15)
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "terminal.fill")
            if service.menuBarUtilization != nil {
                Text("\(Int(utilization.rounded()))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
        .foregroundStyle(color)
        .onAppear {
            service.startPolling()
        }
    }
}
