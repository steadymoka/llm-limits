import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var service: UsageService
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            header

            if let error = service.error {
                errorView(error)
            } else if let usage = service.usage {
                usageList(usage)
            } else if service.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Divider()
            footer
        }
        .padding(12)
        .frame(width: 280)
        .sheet(isPresented: $showSettings) {
            SettingsView(service: service)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkle")
                .foregroundStyle(.orange)
            Text("Claude Usage")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button {
                service.fetchUsage()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .opacity(service.isLoading ? 0.5 : 1)
            .disabled(service.isLoading)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            Button("설정 열기") { showSettings = true }
                .font(.system(size: 11))
        }
    }

    private func usageList(_ usage: UsageData) -> some View {
        VStack(spacing: 10) {
            UsageRowView(title: "5시간 세션", metric: usage.fiveHour)
            UsageRowView(title: "주간 (전체)", metric: usage.sevenDay)
            if let sonnet = usage.sevenDaySonnet {
                UsageRowView(title: "주간 (Sonnet)", metric: sonnet)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("설정") { showSettings = true }
                .font(.system(size: 11))
            Spacer()
            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
        }
        .buttonStyle(.plain)
    }
}
