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
    }
}

struct MenuBarLabel: View {
    @ObservedObject var service: UsageService

    private var utilization: Double {
        service.usage?.maxUtilization ?? 0
    }

    private var color: Color {
        if !service.isConfigured { return .gray }
        if utilization < 50 { return .green }
        if utilization < 80 { return .yellow }
        return .red
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
