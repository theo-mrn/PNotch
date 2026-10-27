import SwiftUI

/// The Atelier, Pixel's home: Pixel on the left, the modules it plugs into the notch on the right,
/// or its wardrobe behind the paintbrush.
struct CompanionView: View {
    @Environment(CompanionManager.self) private var companion
    @Environment(FocusManager.self) private var focus
    @State private var isCustomizing = false

    var body: some View {
        VStack(spacing: 0) {
            NotchHeaderView {
                HoverButton(systemImage: "paintbrush.fill", isActive: isCustomizing) {
                    withAnimation(Motion.fade) { isCustomizing.toggle() }
                }
                .help("Customize")
            }

            HStack(spacing: 14) {
                RobotView(variant: RobotVariant(activity: activity))
                    .frame(width: CompanionMetrics.robotSize.width, height: CompanionMetrics.robotSize.height)
                    .contentShape(Rectangle())
                    .onTapGesture { companion.pet() }
                    .help("Pet")
                    .bloom(2, from: 0.7)

                Group {
                    if isCustomizing {
                        CompanionCustomizationView {
                            withAnimation(Motion.fade) { isCustomizing = false }
                        }
                    } else {
                        AtelierView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .transition(.opacity)
            }
            .padding(.leading, CompanionMetrics.horizontalPadding)
            .frame(height: CompanionMetrics.bodyHeight)
            .pageEntrance()
        }
        // The CPU reading feeds the "hot" mood: sample only while the robot is on screen.
        .onAppear { companion.system.startObserving() }
        .onDisappear { companion.system.stopObserving() }
    }

    /// Headband on while you focus, a warm drink during the break.
    private var activity: CompanionActivity? {
        CompanionActivity.resolve(CompanionActivity.Inputs(page: .companion, focusPhase: focus.runningPhase))
    }
}
