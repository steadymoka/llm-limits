import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var service: UsageService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            if !service.isConfigured {
                emptyView
                    .padding(14)
            } else if let error = service.error {
                errorView(error)
                    .padding(14)
            } else if let usage = service.usage {
                usageList(usage)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            } else if service.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            }

            Divider()

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
        .frame(width: 260)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
            Text("cc-usage")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                service.fetchUsage()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(service.isLoading ? 360 : 0))
                    .animation(
                        service.isLoading
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: service.isLoading
                    )
            }
            .buttonStyle(.plain)
            .disabled(service.isLoading)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "key")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Text("세션 쿠키를 설정해주세요")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Button("설정하기") { openSettings() }
                .font(.system(size: 11))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            Button("설정 열기") { openSettings() }
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
            Button { openSettings() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        if let existing = NSApp.windows.first(where: { $0.title == "Claude 설정" }) {
            existing.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "settings")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
