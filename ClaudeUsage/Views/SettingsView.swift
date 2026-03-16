import SwiftUI

struct SettingsView: View {
    @ObservedObject var service: UsageService
    @Environment(\.dismiss) private var dismiss

    @State private var cookieText: String = ""
    @State private var isFetchingOrg = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claude 세션 쿠키 설정")
                .font(.headline)

            Text("브라우저 개발자도구(F12) → Network 탭 → claude.ai 요청 → Cookie 헤더 값을 복사하세요.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextEditor(text: $cookieText)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: 80)
                .border(Color.gray.opacity(0.3))

            if let status = statusMessage {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(status.contains("성공") ? .green : .red)
            }

            HStack {
                Spacer()
                Button("취소") { dismiss() }
                Button("저장") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(cookieText.isEmpty || isFetchingOrg)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            cookieText = service.sessionCookie
        }
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
                dismiss()
            } else {
                statusMessage = "조직 ID를 가져올 수 없습니다. 쿠키를 확인하세요."
            }
            isFetchingOrg = false
        }
    }
}
