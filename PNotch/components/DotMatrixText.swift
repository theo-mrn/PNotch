import SwiftUI

/// Digits drawn the way an LED display shows them: lit dots on a 5 × 7 grid, the unlit ones barely there.
/// Fits whatever frame it's given, keeping the dots round.
struct DotMatrixText: View {
    let text: String
    var color: Color = Palette.ink
    /// How visible the unlit dots are.
    var unlitOpacity: Double = 0.07
    var glows = true
    /// The dots' size, as a share of the grid: smaller dots look lighter.
    var dotScale: CGFloat = 0.82
    /// Where the digits sit when the frame is wider than they are.
    var alignment: HorizontalAlignment = .center

    var body: some View {
        Canvas { context, size in
            let layout = DotMatrixFont.layout(text)
            guard layout.columns > 0 else { return }
            let pitch = min(size.width / CGFloat(layout.columns), size.height / CGFloat(DotMatrixFont.rows))
            let diameter = pitch * dotScale
            let spare = size.width - pitch * CGFloat(layout.columns)
            let origin = CGPoint(
                x: alignment == .leading ? 0 : alignment == .trailing ? spare : spare / 2,
                y: (size.height - pitch * CGFloat(DotMatrixFont.rows)) / 2
            )

            var lit = Path()
            var unlit = Path()
            for (column, bits) in layout.dots.enumerated() {
                for row in 0 ..< DotMatrixFont.rows {
                    let dot = CGRect(
                        x: origin.x + CGFloat(column) * pitch + (pitch - diameter) / 2,
                        y: origin.y + CGFloat(row) * pitch + (pitch - diameter) / 2,
                        width: diameter,
                        height: diameter
                    )
                    switch bits[row] {
                    case true: lit.addEllipse(in: dot)
                    case false: unlit.addEllipse(in: dot)
                    case nil: break
                    }
                }
            }
            context.fill(unlit, with: .color(color.opacity(unlitOpacity)))
            if glows {
                var glow = context
                glow.addFilter(.blur(radius: diameter * 0.9))
                glow.opacity = 0.55
                glow.fill(lit, with: .color(color))
            }
            context.fill(lit, with: .color(color))
        }
        .accessibilityLabel(Text(verbatim: text))
    }
}

/// A 5 × 7 dot font for digits and the separators of a time or a date.
nonisolated enum DotMatrixFont {
    static let rows = 7

    /// Each glyph is its rows, top to bottom; `1` is a lit dot.
    private static let glyphs: [Character: [String]] = [
        "0": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        ":": ["0", "0", "1", "0", "1", "0", "0"],
        "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
        "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
        "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
        " ": ["000", "000", "000", "000", "000", "000", "000"],
    ]

    struct Layout: Equatable {
        /// Each column of dots, left to right: lit, unlit, or `nil` for the gap between glyphs.
        var dots: [[Bool?]]

        var columns: Int {
            dots.count
        }
    }

    /// The columns of dots for `text`, with a gap between glyphs. Characters without a glyph are left out.
    static func layout(_ text: String) -> Layout {
        var dots: [[Bool?]] = []
        for character in text {
            guard let glyph = glyphs[character] else { continue }
            if !dots.isEmpty {
                dots.append(Array(repeating: nil, count: rows))
            }
            for column in 0 ..< glyph[0].count {
                dots.append(glyph.map { row in
                    row[row.index(row.startIndex, offsetBy: column)] == "1"
                })
            }
        }
        return Layout(dots: dots)
    }
}
