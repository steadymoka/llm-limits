import SwiftUI

/// 한도 하나를 한 줄로 그린다. 줄 자체가 막대여서, 계정 안의 행들을
/// 세로로 훑으면 그대로 막대그래프로 읽힌다.
struct UsageRowView: View {
    let row: UsageRow
    /// 리셋 열을 "9/18 11:00"으로 볼지 "3일 후"로 볼지. 팝오버 전체가 함께 바뀐다.
    let showsAbsoluteReset: Bool
    /// 리셋 칸 자체가 전환 버튼이다. 헤더의 작은 아이콘만으로는 발견되지 않는다.
    var onToggleResetFormat: (() -> Void)?
    /// 기간 막대의 기준 시각. 테스트가 고정된 시각을 넣을 수 있어야 한다.
    var now: Date = .now

    private static let percentColumn: CGFloat = 34
    private static let resetColumn: CGFloat = 56
    private static let height: CGFloat = 20
    private static let radius: CGFloat = 5
    private static let windowBarHeight: CGFloat = 2

    private var utilization: Double {
        min(max(row.metric.utilization, 0), 100)
    }

    private var color: Color {
        if utilization < 50 { return Color(red: 0.0, green: 0.55, blue: 0.35) }
        if utilization < 80 { return Color(red: 0.82, green: 0.52, blue: 0.0) }
        return Color(red: 0.82, green: 0.16, blue: 0.16)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(row.title)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            // 두 열 모두 고정 폭이라 계정이 여럿이어도 숫자가 한 줄로 정렬된다.
            Text("\(Int(utilization.rounded()))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(width: Self.percentColumn, alignment: .trailing)

            resetCell
        }
        .padding(.horizontal, 7)
        .frame(height: Self.height)
        .background { track }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var resetCell: some View {
        let label = Text(resetText)
            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .frame(width: Self.resetColumn, alignment: .trailing)

        if let onToggleResetFormat {
            Button(action: onToggleResetFormat) {
                label.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(showsAbsoluteReset ? "남은 시간으로 보기" : "리셋 시각으로 보기")
        } else {
            label
        }
    }

    /// 이 창이 얼마나 지났는지(0~1). 사용량 막대와 나란히 두면
    /// "쓴 양이 흘러간 시간보다 앞서 있는가"가 두 막대의 길이 차이로 드러난다.
    /// 창 길이나 리셋 시각을 모르는 한도는 그릴 근거가 없어 nil이다.
    var windowProgress: Double? {
        guard let windowMinutes = row.windowMinutes, windowMinutes > 0,
              let resetsAt = row.metric.resetsAt else { return nil }

        let window = Double(windowMinutes) * 60
        let remaining = resetsAt.timeIntervalSince(now)
        return min(max(1 - remaining / window, 0), 1)
    }

    private var track: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.10))
                Rectangle()
                    .fill(color.opacity(0.22))
                    .frame(width: fillWidth(in: geo.size.width))

                if let windowProgress {
                    // 기간은 바닥에 얇게 깐다. 사용량 막대와 같은 굵기로 그리면
                    // 어느 쪽이 사용량인지 헷갈린다.
                    Rectangle()
                        .fill(Color.primary.opacity(0.22))
                        .frame(
                            width: max(geo.size.width * windowProgress, 1),
                            height: Self.windowBarHeight
                        )
                }
            }
        }
        // 채움은 각진 채로 트랙에 잘려야 한다. 채움 자체를 둥글리면
        // 4%짜리 막대가 알약처럼 보여 실제보다 커 보인다.
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
    }

    private func fillWidth(in width: CGFloat) -> CGFloat {
        guard utilization > 0 else { return 0 }
        // 1%도 흔적은 남겨야 "쓴 적 없음"과 구분된다.
        return max(width * utilization / 100, 2)
    }

    private var resetText: String {
        showsAbsoluteReset ? row.metric.resetsAtCompact : row.metric.resetsAtRelative
    }

    private var accessibilityText: String {
        let reset = row.metric.resetsAtFormatted
        let suffix = reset.isEmpty ? "" : ", \(reset) 리셋"
        // 기간 막대는 눈으로만 읽히므로 여기서 말로 갚는다.
        let progress = windowProgress.map { ", 기간 \(Int(($0 * 100).rounded()))% 지남" } ?? ""
        return "\(row.title) \(Int(utilization.rounded()))%\(suffix)\(progress)"
    }
}
