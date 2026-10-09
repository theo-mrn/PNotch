import AppKit
import SwiftUI

// PNotch's one look. Views take their colors, spacing, corners, type and motion from here, never raw values:
// black, warm whites in a few steps, and apricot for what's active.

/// The colors, in Apple's dark system language: pure black, opaque system greys, white text in three
/// strengths, and one flat orange for the main action and what's running. No gradients, no glows.
enum Palette {
    // MARK: Accent

    /// The main action, what's running, what rings. Flat.
    static let accent = Color(hex: 0xF2A65A)
    /// Text and symbols on the accent.
    static let onAccent = Color(hex: 0x1F1205)
    /// Behind something the accent marks, quietly.
    static let accentSoft = accent.opacity(0.16)

    // MARK: Text, on black

    /// Titles and what's read first.
    static let ink = Color.white
    /// Labels and details (Apple's secondary label).
    static let inkSecondary = Color(hex: 0xEBEBF5).opacity(0.6)
    /// Hints and units (Apple's tertiary label).
    static let inkTertiary = Color(hex: 0xEBEBF5).opacity(0.3)
    /// Placeholders and what's off.
    static let inkFaint = Color(hex: 0xEBEBF5).opacity(0.18)

    // MARK: Surfaces, opaque system greys

    /// A quiet fill: a button at rest, a track, a well (system grey 6).
    static let surface = Color(hex: 0x1C1C1E)
    /// A fill that stands out: a card, a hovered row (system grey 5).
    static let surfaceRaised = Color(hex: 0x2C2C2E)
    /// What's selected among its siblings, like a segmented control (system grey 4).
    static let selection = Color(hex: 0x3A3A3C)
    /// Hairlines between rows.
    static let line = Color(hex: 0x2C2C2E)

    // MARK: Meaning

    /// A second series beside the accent in a chart.
    static let muted = Color(hex: 0xAEAEB2)
    /// Late, deleting, too hot (system red). Always with a word or a symbol, never alone.
    static let danger = Color(hex: 0xFF453A)
}

/// The spacing steps, on a grid of 4.
enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

/// The corner radii.
enum Radius {
    /// Chips, small wells.
    static let s: CGFloat = 8
    /// Buttons that aren't capsules, rows.
    static let m: CGFloat = 12
    /// Cards, artwork.
    static let l: CGFloat = 16
}

/// The type scale. SF Pro for words, SF Pro Rounded for figures shown large.
enum TypeScale {
    /// Units, counts, the smallest hints.
    static let caption = Font.system(size: 11, weight: .medium)
    /// Secondary details under a title.
    static let footnote = Font.system(size: 12, weight: .medium)
    /// Running text.
    static let body = Font.system(size: 13)
    /// Buttons and labels that act.
    static let label = Font.system(size: 13, weight: .semibold)
    /// The title of a row or a card.
    static let headline = Font.system(size: 15, weight: .semibold)
    /// The one thing a page is about.
    static let title = Font.system(size: 19, weight: .semibold)

    /// Figures shown large: a time, a percentage.
    static func figure(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// The motion: springs with life in them, that overshoot a little and settle, like something organic.
/// Plain fades when macOS asks to reduce motion.
enum Motion {
    static var reducesMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Stretches every animation, to look at one frame by frame. Always 1 in the app.
    static var slowdown: Double = 1

    /// A spring of `duration`, stretched by `slowdown`.
    static func spring(_ duration: Double, bounce: Double) -> Animation {
        .spring(duration: duration * slowdown, bounce: bounce)
    }

    /// A smooth curve of `duration`, stretched by `slowdown`.
    static func smooth(_ duration: Double) -> Animation {
        .smooth(duration: duration * slowdown)
    }

    /// Colors on hover: quick and quiet, nothing moves.
    static var hover: Animation {
        smooth(0.18)
    }

    /// Something appearing or leaving in place.
    static var fade: Animation {
        smooth(0.28)
    }

    /// Most changes of state: a lively spring that overshoots a touch, then settles.
    static var standard: Animation {
        reducesMotion ? smooth(0.2) : spring(0.48, bounce: 0.26)
    }

    /// A panel growing, a page turning into another: rounder, more elastic.
    static var layout: Animation {
        reducesMotion ? smooth(0.24) : spring(0.56, bounce: 0.3)
    }

    /// Pressing, hovering a card: short and springy.
    static var snappy: Animation {
        reducesMotion ? smooth(0.15) : spring(0.3, bounce: 0.42)
    }

    /// A small reward, like a box ticked or Pixel popping in: the bounciest.
    static var pop: Animation {
        reducesMotion ? smooth(0.2) : spring(0.42, bounce: 0.52)
    }

    /// How long the `order`-th element waits before it blooms: they come one after the other.
    static func stagger(_ order: Int) -> TimeInterval {
        reducesMotion ? 0 : (0.02 + Double(order) * 0.04) * slowdown
    }
}
