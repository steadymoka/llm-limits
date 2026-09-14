import SwiftUI

/// 계정 하나의 사용량 블록. 계정이 여럿일 때 어느 계정의 숫자인지,
/// 그 숫자가 어디서 언제 온 것인지를 헤더 한 줄로 밝힌다.
struct AccountSectionView: View {
    let card: AccountCard
    /// 계정이 하나뿐이면 "어느 계정이 활성인지"가 정보를 더하지 않는다.
    let showsActiveBadge: Bool
    let isExpanded: Bool
    let isCollapsible: Bool
    let showsAbsoluteReset: Bool
    let onToggleResetFormat: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            header

            if isExpanded {
                body(for: card)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        // 접을 수 없는 계정까지 Button으로 감싸면 비활성 스타일이 라벨을 흐리게 만든다.
        if isCollapsible {
            Button(action: onToggle) { headerRow }
                .buttonStyle(.plain)
        } else {
            headerRow
        }
    }

    private var headerRow: some View {
        HStack(spacing: 5) {
            Image(systemName: card.isActive ? "circle.fill" : "circle")
                .font(.system(size: 6))
                .foregroundStyle(card.isActive ? Color.accentColor : Color.secondary.opacity(0.45))

            Text(card.shortLabel)
                .font(.system(size: 10.5, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            if card.isActive && showsActiveBadge {
                Text("ACTIVE")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                    .tracking(0.5)
            }

            Spacer(minLength: 4)

            if let plan = card.planLabel {
                Text(plan)
                    .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if let source = card.sourceBadge() {
                Text(source)
                    .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if isCollapsible {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func body(for card: AccountCard) -> some View {
        if !card.rows.isEmpty {
            VStack(spacing: 2) {
                ForEach(card.rows) { row in
                    UsageRowView(
                        row: row,
                        showsAbsoluteReset: showsAbsoluteReset,
                        onToggleResetFormat: onToggleResetFormat
                    )
                }
            }

            if let error = card.error {
                InlineStatus(message: error, color: .red)
                    .padding(.top, 2)
            }
        } else if card.isLoading {
            InlineLoading()
        } else if let error = card.error {
            InlineStatus(message: error, color: .red)
        } else {
            HStack(spacing: 5) {
                Image(systemName: card.isUnlimited ? "infinity" : "minus")
                Text(card.isUnlimited ? "UNLIMITED" : "한도 정보 없음")
                Spacer()
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }
}

struct InlineStatus: View {
    let message: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(color)
                .padding(.top, 1)
            Text(message)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

struct InlineLoading: View {
    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
            Text("SYNCING")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
