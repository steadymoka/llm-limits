import Foundation

/// 소스별 결과를 계정 단위로 합친다. orgId가 같으면 한 계정이고,
/// 더 상세하고 신선한 쿠키 데이터가 Orca 스냅샷을 덮는다.
enum AccountRegistry {
    struct CookieState: Equatable {
        var usage: UsageData?
        var error: String?
        var fetchedAt: Date?
        var isLoading: Bool

        init(usage: UsageData? = nil, error: String? = nil, fetchedAt: Date? = nil, isLoading: Bool = false) {
            self.usage = usage
            self.error = error
            self.fetchedAt = fetchedAt
            self.isLoading = isLoading
        }
    }

    static func claudeCards(
        credentials: [ClaudeCredential],
        cookieStates: [String: CookieState],
        orca: OrcaSnapshot?
    ) -> [AccountCard] {
        // Orca가 아는 계정이 기준. 이메일 라벨과 활성 표시가 여기서 온다.
        var cards = (orca?.claude ?? []).map { entry in
            AccountCard(
                key: entry.claudeKey,
                label: entry.label,
                isActive: entry.isActive,
                rows: entry.rows,
                source: entry.rows.isEmpty ? nil : .orca,
                fetchedAt: entry.updatedAt,
                isLoading: entry.isFetching,
                error: entry.error
            )
        }

        for credential in credentials {
            let key = AccountKey.claude(orgId: credential.orgId)
            let state = cookieStates[credential.orgId] ?? CookieState()

            if let index = cards.firstIndex(where: { $0.key == key }) {
                cards[index] = applying(state, to: cards[index])
            } else {
                var card = AccountCard(
                    key: key,
                    label: credential.label ?? "조직 \(credential.orgId.prefix(8))"
                )
                card = applying(state, to: card)
                cards.append(card)
            }
        }

        return sorted(cards)
    }

    static func codexCards(
        usage: CodexUsageData?,
        error: String?,
        fetchedAt: Date?,
        isLoading: Bool,
        isInstalled: Bool,
        orcaLabel: String?
    ) -> [AccountCard] {
        guard isInstalled || usage != nil else { return [] }
        return [
            AccountCard(
                key: .localCodex,
                label: orcaLabel ?? "Codex 로그인",
                isActive: true,
                rows: usage?.displayLimits ?? [],
                planLabel: usage?.planLabel,
                source: usage == nil ? nil : .codexCLI,
                fetchedAt: fetchedAt,
                isLoading: isLoading,
                error: error,
                isUnlimited: usage?.isUnlimited ?? false
            ),
        ]
    }

    /// 쿠키 결과가 있으면 그 계정의 표시 데이터를 승격한다.
    /// 쿠키 호출이 실패하면 Orca 행을 남겨두고 오류만 덧붙인다.
    private static func applying(_ state: CookieState, to card: AccountCard) -> AccountCard {
        var card = card
        if let usage = state.usage {
            card.rows = usage.rows
            card.source = .cookie
            card.fetchedAt = state.fetchedAt
        }
        if let error = state.error {
            card.error = error
        }
        card.isLoading = card.isLoading || state.isLoading
        return card
    }

    /// 활성 계정이 앞, 나머지는 라벨 순. 순서가 흔들리면 메뉴바 숫자 위치가 바뀐다.
    private static func sorted(_ cards: [AccountCard]) -> [AccountCard] {
        cards.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }
}
