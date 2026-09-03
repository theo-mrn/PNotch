import CoreGraphics
import Foundation
import Testing
@testable import PNotch

struct NotchGeometryTests {
    /// 14" MacBook Pro at its default resolution.
    private let macBookPro14 = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        physicalNotchSize: CGSize(width: 185, height: 32)
    )

    @Test func usesThePhysicalNotch() {
        #expect(macBookPro14.hasPhysicalNotch)
        #expect(macBookPro14.closedSize == CGSize(width: 185, height: 32))
    }

    @Test func fallsBackToADrawnNotch() {
        let externalDisplay = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440), physicalNotchSize: nil)

        #expect(!externalDisplay.hasPhysicalNotch)
        #expect(externalDisplay.closedSize == NotchMetrics.fallbackNotchSize)
    }

    @Test func windowIsNoWiderThanTheWidestPage() {
        let overflow = NotchCornerRadii.opened.top + NotchMetrics.shadowPadding
        #expect(macBookPro14.windowFrame.width == MusicMetrics.width + 2 * overflow)
    }

    @Test func musicIsACompactPlayer() {
        let music = macBookPro14.openedSize(for: .music)

        #expect(music.width == MusicMetrics.width)
        #expect(macBookPro14.windowFrame.height >= music.height)
    }

    @Test func headerWingsHoldTheTabsSideAndTheButtonsSide() {
        // Right of the camera: up to two page buttons and settings.
        let buttons = 3 * NotchHeaderMetrics.controlHeight + 2 * 6
        for layout in [NotchLayout.music] {
            let width = macBookPro14.openedSize(for: layout).width
            let wing = (width - 2 * NotchHeaderMetrics.horizontalPadding - 185 - NotchMetrics.cameraClearance) / 2
            #expect(buttons <= wing, "\(layout)")
        }
    }

    @Test func everyModuleTabFitsLeftOfTheCameraWithoutScrolling() {
        let all = NotchModules.catalog.count
        for layout in [NotchLayout.music] {
            let width = macBookPro14.openedSize(for: layout).width
            let wing = (width - 2 * NotchHeaderMetrics.horizontalPadding - 185 - NotchMetrics.cameraClearance) / 2
            #expect(NotchHeaderMetrics.iconBarWidth(count: all) <= wing, "\(layout)")
            // A wider camera housing, 200 points: the tight bar still fits.
            let narrowWing = (width - 2 * NotchHeaderMetrics.horizontalPadding - 200 - NotchMetrics.cameraClearance) / 2
            #expect(NotchHeaderMetrics.iconBarWidth(count: all, tight: true) <= narrowWing, "\(layout)")
        }
    }

    @Test func windowHangsFromTheTopCenterOfItsScreen() {
        let secondaryDisplay = NotchGeometry(
            screenFrame: CGRect(x: 1512, y: 200, width: 1920, height: 1080),
            physicalNotchSize: nil
        )
        let frame = secondaryDisplay.windowFrame

        #expect(frame.maxY == secondaryDisplay.screenFrame.maxY)
        #expect(frame.midX == secondaryDisplay.screenFrame.midX)
        #expect(frame.width <= secondaryDisplay.screenFrame.width)
        #expect(frame.height >= secondaryDisplay.openedSize(for: .music).height)
    }
}
