// DesignWindowFitTests.swift: a Design window opens with its page fitted to
// the canvas it settles at, not to the first size the canvas reports. The
// split view lays the canvas out a few times on the way up (about 212 × 311,
// then 540 × 771, then 748 × 771 in a 1280 × 820 window); a fit taken at the
// first size left the 1440 × 1024 page about 80 pt wide. The window is hosted
// off screen through the render-budget harness, nested in BodyCountSuites so
// it never runs beside the suites that count window bodies. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignWindowFitTests {
        @Test(.timeLimit(.minutes(2))) func theFirstPageFitsTheSettledCanvas() async throws {
            var cards = DesignFixtures.cards
            cards.useServices(.fake)
            let w = RenderBudgetWindow(DesignWindow(seed: cards))
            defer { w.close() }
            try await w.settle(800)
            let page = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            // A fit to the settled canvas (about 748 × 771, less the palette) draws the page
            // several hundred points wide; one taken at the first layout pass draws it under 100.
            #expect(page.width > 400, "the page is \(page.width) pt wide")
            #expect(abs(page.width / page.height - 1440.0 / 1024.0) < 0.02)
        }
    }
}
#endif
