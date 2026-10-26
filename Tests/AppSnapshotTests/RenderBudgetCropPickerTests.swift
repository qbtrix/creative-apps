// RenderBudgetCropPickerTests.swift (orientation-crop OC-6's budget row): the gallery's `crop` page on 4:5 in a
// key-capable 1280 x 820 window; each press of the orientation toggle runs the page's body at most once and turns the
// frame. The crop snapshots sit beside it: suite-gallery-crop-{light,dark}.png, 4:5 picked with portrait on. Nested
// in BodyCountSuites: it reads global body counters. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetCropPickerTests {
        @Test(.timeLimit(.minutes(2))) func swapInOneBody() async throws {
            let w = RenderBudgetWindow(GalleryCropPage(aspect: .ratio(width: 4, height: 5)).allowsWindowActivationEvents(), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            let bodies = { () -> Int? in
                #if DEBUG
                return GalleryCropPage.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            #expect(w.label("suite.gallery.crop.frame") == "Crop frame landscape")
            // Clicked, not keyed: a test's key event may miss a SwiftUI shortcut. The journey presses X.
            let toggle = try #require(await w.element("suite.crop.orientation"), "no orientation toggle (suite.crop.orientation)")
            for (press, shape) in ["portrait", "landscape", "portrait"].enumerated() {
                let step = try await w.measure("crop swap \(press + 1)", bodies: bodies) {
                    try await w.ticks(1) { _ in w.click(at: CGPoint(x: toggle.midX, y: toggle.midY)) }
                }
                expectBodies(step, atMost: 1, target: 1)
                #expect(w.label("suite.gallery.crop.frame") == "Crop frame \(shape)", "press \(press + 1)")
            }
        }
    }
}

@MainActor @Suite struct SuiteCropPickerSnapshots {
    @Test func screens() throws {
        for scheme in [ColorScheme.light, .dark] {
            let page = GalleryCropPage(aspect: .ratio(width: 4, height: 5), orientation: .portrait)
            try snapshot(page, name: "suite-gallery-crop-\(scheme.name)", scheme: scheme)
        }
    }
}
#endif
