import Foundation

struct CodexUsageData: Decodable, Equatable {
    let rateLimits: CodexRateLimitSnapshot
    let rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?

    var displayLimits: [CodexDisplayLimit] {
        snapshots.flatMap { entry in
            let windows = [entry.snapshot.primary, entry.snapshot.secondary]
                .enumerated()
                .compactMap { index, window -> CodexDisplayLimit? in
                    guard let window else { return nil }
                    let windowName = window.displayName ?? (index == 0 ? "기본 한도" : "보조 한도")
                    let title = entry.name.map { "\($0) · \(windowName)" } ?? windowName

                    return CodexDisplayLimit(
                        id: "\(entry.id)-\(index)",
                        title: title,
                        metric: window.asUsageMetric,
                        windowDurationMinutes: window.windowDurationMins
                    )
                }
            return windows
        }
    }

    var representativeUtilization: Double? {
        let limits = displayLimits
        let shortTerm = limits
            .filter { ($0.windowDurationMinutes ?? .max) <= 300 }
            .map(\.metric.utilization)
            .max()
        return shortTerm ?? limits.map(\.metric.utilization).max()
    }

    var maxUtilization: Double {
        displayLimits.map(\.metric.utilization).max() ?? 0
    }

    var isUnlimited: Bool {
        snapshots.contains { $0.snapshot.credits?.unlimited == true }
    }

    var planLabel: String? {
        guard let plan = rateLimits.planType, plan != "unknown" else { return nil }
        return plan.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    private var snapshots: [(id: String, name: String?, snapshot: CodexRateLimitSnapshot)] {
        var result = [(id: String, name: String?, snapshot: CodexRateLimitSnapshot)]()
        let defaultId = rateLimits.limitId ?? "codex"
        result.append((defaultId, rateLimits.limitName, rateLimits))

        let additional = (rateLimitsByLimitId ?? [:])
            .sorted { lhs, rhs in
                let lhsName = lhs.value.limitName ?? lhs.key
                let rhsName = rhs.value.limitName ?? rhs.key
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }

        for (key, snapshot) in additional {
            let duplicatesDefault = snapshot == rateLimits
                || (snapshot.limitId != nil && snapshot.limitId == rateLimits.limitId)
            guard !duplicatesDefault else { continue }
            result.append((snapshot.limitId ?? key, snapshot.limitName, snapshot))
        }

        return result
    }
}

struct CodexRateLimitSnapshot: Decodable, Equatable {
    let limitId: String?
    let limitName: String?
    let primary: CodexRateLimitWindow?
    let secondary: CodexRateLimitWindow?
    let credits: CodexCreditsSnapshot?
    let planType: String?
}

struct CodexRateLimitWindow: Decodable, Equatable {
    let usedPercent: Int
    let windowDurationMins: Int64?
    let resetsAt: Int64?

    var displayName: String? {
        guard let minutes = windowDurationMins else { return nil }
        switch minutes {
        case 300:
            return "5시간 세션"
        case 10_080:
            return "주간"
        case 1_440:
            return "일간"
        default:
            if minutes.isMultiple(of: 1_440) {
                return "\(minutes / 1_440)일"
            }
            if minutes.isMultiple(of: 60) {
                return "\(minutes / 60)시간"
            }
            return "\(minutes)분"
        }
    }

    var asUsageMetric: UsageMetric {
        let resetString = resetsAt.map { timestamp in
            ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
        }
        return UsageMetric(utilization: Double(usedPercent), resetsAt: resetString)
    }
}

struct CodexCreditsSnapshot: Decodable, Equatable {
    let balance: String?
    let hasCredits: Bool
    let unlimited: Bool
}

struct CodexDisplayLimit: Identifiable, Equatable {
    let id: String
    let title: String
    let metric: UsageMetric
    let windowDurationMinutes: Int64?
}
