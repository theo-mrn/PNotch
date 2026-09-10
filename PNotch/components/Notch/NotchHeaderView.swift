import SwiftUI

/// Top row of the opened notch, level with the menu bar and split around the camera housing:
/// tabs on the left; the page's own buttons, then settings, on the right.
struct NotchHeaderView<PageActions: View>: View {
    @ViewBuilder let pageActions: () -> PageActions

    @Environment(PNotchViewModel.self) private var vm
    @Environment(PNotchViewCoordinator.self) private var coordinator

    var body: some View {
        HStack(spacing: 0) {
            NotchTabBar()
                .bloom(0, from: 0.94, onlyOnOpening: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear
                .frame(width: vm.geometry.notchSize.width + NotchMetrics.cameraClearance)

            HStack(spacing: 6) {
                pageActions()

                HoverButton(systemImage: "gearshape.fill") {
                    coordinator.showSettings()
                }
                .help("Settings")
            }
            .bloom(1, from: 0.94, onlyOnOpening: true)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, NotchHeaderMetrics.horizontalPadding)
        .frame(height: vm.geometry.notchSize.height)
    }
}

extension NotchHeaderView where PageActions == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}
