import SwiftUI

struct UsageRowView: View {
    let title: String
    let metric: UsageMetric?

    private var utilization: Double {
        metric?.utilization ?? 0
    }

    private var color: Color {
        if utilization < 50 { return Color(red: 0.0, green: 0.55, blue: 0.35) }
        if utilization < 80 { return Color(red: 0.8, green: 0.5, blue: 0.0) }
        return Color(red: 0.8, green: 0.15, blue: 0.15)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(color.opacity(0.15))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(color)
                        .frame(width: geo.size.width * min(utilization, 100) / 100, height: 5)
                }
            }
            .frame(height: 5)

            if let metric, !metric.resetsAtRelative.isEmpty {
                Text("\(metric.resetsAtFormatted) (\(metric.resetsAtRelative))")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
