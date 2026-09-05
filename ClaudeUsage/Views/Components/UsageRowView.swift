import SwiftUI

struct UsageRowView: View {
    let title: String
    let metric: UsageMetric?

    private var utilization: Double {
        metric?.utilization ?? 0
    }

    private var color: Color {
        guard metric != nil else { return .secondary }
        if utilization < 50 { return Color(red: 0.0, green: 0.55, blue: 0.35) }
        if utilization < 80 { return Color(red: 0.8, green: 0.5, blue: 0.0) }
        return Color(red: 0.8, green: 0.15, blue: 0.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(metric == nil ? "--" : "\(Int(utilization.rounded()))%")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.13))
                        .frame(height: 3)

                    Capsule()
                        .fill(color)
                        .frame(
                            width: geo.size.width * min(max(utilization, 0), 100) / 100,
                            height: 3
                        )
                }
            }
            .frame(height: 3)

            if let metric, !metric.resetsAtRelative.isEmpty {
                HStack(spacing: 4) {
                    Text("RESET")
                        .fontWeight(.semibold)
                    Text(metric.resetsAtFormatted)
                    Text("·")
                    Text(metric.resetsAtRelative)
                }
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
