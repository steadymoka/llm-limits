import SwiftUI

struct SettingsView: View {
    @ObservedObject var service: UsageService
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var cookieText: String = ""
    @State private var isFetchingOrg = false
    @State private var statusMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claude 세션 쿠키 설정")
                .font(.headline)

            Text("브라우저 개발자도구(F12) → Network 탭 → claude.ai 요청 → Cookie 헤더 값을 복사하세요.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField("쿠키 값을 붙여넣으세요", text: $cookieText, axis: .vertical)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(4...8)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                .focused($isFocused)

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
        .padding(20)
        .frame(width: 420)
        .onAppear {
            cookieText = service.sessionCookie
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.activate(ignoringOtherApps: true)
                isFocused = true
            }
        }
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
