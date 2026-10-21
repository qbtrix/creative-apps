// RenderBudgetLibraryFileDropTests.swift (file-flow LF-5): what a file drag over the Library window costs
// (Tests/render-budgets.md), through the harness (RenderBudgetHarness.swift), on the `samples` fixture.
// 120 pointer moves cross the window while files hover; the window body may run at most twice (the mark's
// arrival and exit), since the mark is an overlay of its own. A real drag session can't run in a test
// process, and the drop modifier's hover is private state its delegate sets: the hook that drives it in a
// test (`SuiteDropHover`) comes with SF-4, so the test is disabled until then and moves the pointer only.
// Nested in BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SuiteShell
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryFileDropTests {
        @Test(.disabled("waits on SF-4"), .timeLimit(.minutes(2))) func dragHoverInTwoBodies() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "samples"]))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return LibraryWindow.bodyRuns
                #else
                return nil
                #endif
            }
            // The launch restore and the first thumbnails aren't the hover's cost.
            try await w.settle(untilStable: bodies, turns: 8)
            let step = try await w.measure("library file drag hover, 120 moves", bodies: bodies) {
                // SF-4: the files enter here (the hover planned: the mark arrives) ...
                try await w.ticks(120) { i in w.send(.mouseMoved, at: CGPoint(x: 160 + 8 * i, y: 400)) }
                // ... and leave here (the mark goes).
            }
            #expect(w.label(SuiteFileControlID.dropMark) == nil, "the mark stayed after the files left")
            // The mark is an overlay: the window renders at most for its arrival and exit. Target: 0.
            expectBodies(step, atMost: 2, target: 0)
        }
    }
}
#endif
