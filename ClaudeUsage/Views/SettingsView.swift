import SwiftUI

struct SettingsView: View {
    @ObservedObject var service: UsageService
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var cookieText: String = ""
    @State private var isFetchingOrg = false
    @State private var statusMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 7) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("LLM Limits")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                Spacer()
                Text("CONFIG")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(0.7)
            }

            Divider()

            HStack(spacing: 6) {
                ProviderMark(provider: .claude)
                Text("CLAUDE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(0.7)
                Spacer()
                Text("SESSION COOKIE")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Text("브라우저 개발자도구(F12) → Network 탭 → claude.ai 요청 → Cookie 헤더 값을 복사하세요.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)

            TextField("쿠키 값을 붙여넣으세요", text: $cookieText, axis: .vertical)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(7)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.25)))
                .focused($isFocused)

            HStack(alignment: .top, spacing: 8) {
                ProviderMark(provider: .codex)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("CODEX")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.7)
                        Text(codexStatus)
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(codexStatusColor)
                    }
                    Text("설치된 Codex CLI의 ChatGPT 로그인을 자동으로 사용합니다. 별도 설정은 필요 없습니다.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))

            if let status = statusMessage {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(status.contains("성공") ? .green : .red)
            }

            HStack {
                Spacer()
                Button("취소") { closeSettings() }
                Button("저장") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(cookieText.isEmpty || isFetchingOrg)
            }
        }
        .padding(16)
        .frame(width: 404)
        .onAppear {
            cookieText = service.sessionCookie
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.activate(ignoringOtherApps: true)
                isFocused = true
            }
        }
    }

    private var codexStatus: String {
        if service.isCodexLoading { return "SYNCING" }
        if service.codexUsage != nil { return "CONNECTED" }
        if service.codexError != nil { return "ERROR" }
        if service.isCodexInstalled { return "DETECTED" }
        return "NOT FOUND"
    }

    private var codexStatusColor: Color {
        if service.codexError != nil { return .red }
        if service.codexUsage != nil { return .green }
        return .secondary.opacity(0.7)
    }

    private func closeSettings() {
        NSApp.setActivationPolicy(.accessory)
        dismissWindow(id: "settings")
    }

    private func save() {
        isFetchingOrg = true
        statusMessage = "조직 ID 가져오는 중..."

        service.sessionCookie = cookieText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            if let orgId = await service.fetchOrganizationId() {
                service.organizationId = orgId
                statusMessage = "성공! 조직 ID: \(orgId.prefix(8))..."
                service.startPolling()

                try? await Task.sleep(for: .seconds(1))
                closeSettings()
            } else {
                statusMessage = "조직 ID를 가져올 수 없습니다. 쿠키를 확인하세요."
            }
            isFetchingOrg = false
        }
    }
}
