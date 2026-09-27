import SwiftUI

/// Card of the System page: a titled metric with its value, a detail line and a chart or gauge.
struct MetricTile<Value: View, Footer: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    var detail: String = ""
    @ViewBuilder let value: () -> Value
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SystemMetricsLayout.tileCornerRadius, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text(title)
                    .foregroundStyle(Palette.inkSecondary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            .font(.system(size: 11, weight: .semibold))
            .labelStyle(TightLabelStyle())
            .padding(.bottom, 5)

            value()
                .foregroundStyle(Palette.ink)

            Text(detail)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Palette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 1)

            Spacer(minLength: 6)

            footer()
                .frame(height: 26)
        }
        .padding(11)
        .frame(width: SystemMetricsLayout.tileSize.width, height: SystemMetricsLayout.tileSize.height, alignment: .topLeading)
        .background(shape.fill(Palette.surface))
        .overlay(shape.strokeBorder(Palette.surface, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Big number of a tile, rolling digits when it changes.
struct MetricValueText: View {
    let text: String
    var size: CGFloat = 22

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(.numericText())
            .animation(Motion.standard, value: text)
    }
}

/// Horizontal fill gauge, for capacities rather than histories.
struct MetricBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceRaised)
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .animation(Motion.fade, value: fraction)
    }
}

private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
    }
}
