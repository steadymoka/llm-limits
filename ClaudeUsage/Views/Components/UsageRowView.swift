import SwiftUI

struct UsageRowView: View {
    let title: String
    let metric: UsageMetric?

    private var utilization: Double {
        metric?.utilization ?? 0
    }

    private var color: Color {
        if utilization < 50 { return .green }
        if utilization < 80 { return .yellow }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            ProgressView(value: min(utilization, 100), total: 100)
                .tint(color)

            if let resetText = metric?.resetsAtRelative, !resetText.isEmpty {
                Text("리셋: \(resetText)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
