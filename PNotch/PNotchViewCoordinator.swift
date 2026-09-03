import Observation
import SwiftUI

/// App-wide UI state that is not tied to the notch geometry: navigation to Settings.
@Observable
final class PNotchViewCoordinator {
    @ObservationIgnored var onShowSettings: (() -> Void)?

    func showSettings() {
        onShowSettings?()
    }
}
