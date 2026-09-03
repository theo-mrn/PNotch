import SwiftUI

extension Animation {
    /// The notch grows out of the camera like something alive: it overshoots, then settles.
    static var notchOpen: Animation {
        Motion.reducesMotion ? Motion.smooth(0.25) : Motion.spring(0.58, bounce: 0.34)
    }

    /// It folds back quicker than it opened, with a small squash as it lands.
    static var notchClose: Animation {
        Motion.reducesMotion ? Motion.smooth(0.2) : Motion.spring(0.42, bounce: 0.16)
    }

    /// Under the pointer it breathes in, elastic.
    static var notchHover: Animation {
        Motion.reducesMotion ? Motion.smooth(0.18) : Motion.spring(0.38, bounce: 0.45)
    }

    /// A sneak peek springs out on both sides of the camera.
    static var sneakPeek: Animation {
        Motion.reducesMotion ? Motion.smooth(0.22) : Motion.spring(0.5, bounce: 0.36)
    }
}

extension AnyTransition {
    static func blur(radius: CGFloat) -> AnyTransition {
        .modifier(active: BlurModifier(radius: radius), identity: BlurModifier(radius: 0))
    }

    /// Content of the opened notch. Its pieces bloom in one after the other on their own (`bloom`);
    /// on closing it's drawn back into the camera: smaller, blurred, gone before the shape lands.
    static var notchContent: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(Motion.smooth(0.12)),
            removal: .opacity
                .combined(with: .scale(scale: 0.86, anchor: .top))
                .combined(with: .blur(radius: 10))
                .animation(Motion.smooth(0.18))
        )
    }

    /// The page left when another tab is chosen: it melts away while the new one slides in.
    static var pageLeaving: AnyTransition {
        .opacity
            .combined(with: .blur(radius: 8))
            .combined(with: .scale(scale: 0.97, anchor: .top))
            .animation(Motion.smooth(0.24))
    }
}

private struct BlurModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}
