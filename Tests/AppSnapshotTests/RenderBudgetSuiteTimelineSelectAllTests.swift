// RenderBudgetSuiteTimelineSelectAllTests.swift (timeline-select-all TSA-2,
// Quality tests): the gallery's `timeline-long` page (300 lanes over 10,000
// frames) in a 1280 x 820 window. Select All Keys picks every key in one
// page body and one strip body. The harness never has a key window, so it
// cannot press ⌘A; it clicks the page's Select All Keys button, which runs
// the same closure the strip's ⌘A route calls (the journey presses ⌘A).
// Nested in BodyCountSuites: it reads global body counters. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetSuiteTimelineSelectAllTests {
        @Test(.timeLimit(.minutes(2))) func selectAllInOneBody() async throws {
            let w = RenderBudgetWindow(GalleryTimelinePage(fixture: .long))
            defer { w.close() }
            try await w.settle(600)
            let pageBodies = { () -> Int? in
                #if DEBUG
                return GalleryTimelinePage.bodyRuns
                #else
                return nil
                #endif
            }
            let stripBodies = { () -> Int? in
                #if DEBUG
                return TimelineStrip<String>.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: pageBodies)
            let button = try #require(await w.element("gallery.timeline.selectAll"), "no Select All Keys button")
            let strip = stripBodies()
            let step = try await w.measure("timeline-long select all", bodies: pageBodies) {
                try await w.ticks(1) { _ in w.click(at: CGPoint(x: button.midX, y: button.midY)) }
            }
            expectBodies(step, atMost: 1, target: 1)
            if let before = strip, let after = stripBodies() {
                #expect(after - before <= 1, "Select All Keys ran the strip's body \(after - before) times")
            }
            #expect(w.label("suite.gallery.log")?.hasSuffix("select-all") == true, "the click logged no select-all")
        }
    }
}
#endif
