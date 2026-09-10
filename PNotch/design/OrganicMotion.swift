import SwiftUI

// The pieces that make PNotch move like something alive: content blooming in one piece after the other,
// pages sliding in from the tab chosen, buttons giving under the click.

extension View {
    /// Blooms in when it appears: out of a blur, a little small and high, then in place with a spring.
    /// `order` staggers it after the elements before it. With `onlyOnOpening`, it blooms when the notch opens
    /// but stays put when the tab changes, like the header.
    func bloom(_ order: Int = 0, from scale: CGFloat = 0.9, onlyOnOpening: Bool = false) -> some View {
        modifier(Bloom(order: order, scale: scale, onlyOnOpening: onlyOnOpening))
    }

    /// The body of a page: it slides in sideways from the side of the tab chosen.
    func pageEntrance() -> some View {
        modifier(PageEntrance())
    }
}

private struct Bloom: ViewModifier {
    let order: Int
    let scale: CGFloat
    let onlyOnOpening: Bool

    @Environment(PNotchViewModel.self) private var vm
    @State private var isShown = false

    func body(content: Content) -> some View {
        let reduces = Motion.reducesMotion
        content
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown || reduces ? 1 : scale, anchor: .top)
            .offset(y: isShown || reduces ? 0 : -12)
            .blur(radius: isShown || reduces ? 0 : 8)
            .onAppear {
                if onlyOnOpening, vm.pageDirection != 0 {
                    isShown = true
                    return
                }
                withAnimation(Motion.standard.delay(Motion.stagger(order))) {
                    isShown = true
                }
            }
    }
}

private struct PageEntrance: ViewModifier {
    @Environment(\.pageSlideOffset) private var offset

    func body(content: Content) -> some View {
        content.offset(x: offset)
    }
}

extension EnvironmentValues {
    /// How far the body of an arriving page still is from its place, during its transition.
    @Entry var pageSlideOffset: CGFloat = 0
}

/// Hands the arriving page's offset down to its body, frame after frame.
private struct PageSlide: ViewModifier, Animatable {
    var offset: CGFloat

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func body(content: Content) -> some View {
        content.environment(\.pageSlideOffset, offset)
    }
}

extension AnyTransition {
    /// The page arriving when a tab is chosen: its body slides in from the side of the tab, with a spring.
    /// The header stays put: only views marked `pageEntrance()` move.
    static func pageArriving(from direction: CGFloat) -> AnyTransition {
        let distance = Motion.reducesMotion ? 0 : direction * 72
        return AnyTransition.modifier(active: PageSlide(offset: distance), identity: PageSlide(offset: 0))
            .animation(Motion.layout)
            .combined(with: .opacity.animation(Motion.smooth(0.14)))
    }
}

/// A plain button that gives under the click and springs back.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !Motion.reducesMotion ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
