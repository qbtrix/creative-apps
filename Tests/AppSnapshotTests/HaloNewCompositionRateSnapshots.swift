// HaloNewCompositionRateSnapshots.swift (frame-rates FR-8b, slice FR-halo): New Composition with 29.97 fps
// picked from the rate menu's nine rates, 10 s long; the Frame Rate menu reads "29.97 fps". An offscreen
// render can't show the menu open, so the shot holds the closed menu with an exact rate; the journey
// HJ-FR (HaloTimelineJourneyTests.testCompositionAt2997) opens it. Writes
// `halo-new-composition-rates-{light,dark}.png`. macOS only.
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp

@Suite struct HaloNewCompositionRateSnapshots {
    private let ntsc = CompositionSettings(name: "NTSC", frameRate: FrameRate(numerator: 30000, denominator: 1001), durationSeconds: 10)

    @Test func newCompositionAt2997() throws {
        #expect(ntsc.isValid && ntsc.durationFrames == 300)
        try snapshot(NewCompositionSheet(settings: ntsc), name: "halo-new-composition-rates-light", scheme: .light)
        try snapshot(NewCompositionSheet(settings: ntsc), name: "halo-new-composition-rates-dark", scheme: .dark)
    }
}
