// RenderBudgetLibraryFileDropTests.swift (file-flow LF-5): what a file drag over the Library window costs
// (Tests/render-budgets.md), through the harness (RenderBudgetHarness.swift), on the `samples` fixture. A real
// drag session can't run in a test process, so the suite's drop modifier is hosted around the window with a
// hover the test drives the way the modifier's delegate does (SuiteDropHover, SF-4): three JPEGs enter and are
// planned as an import, 120 pointer moves cross the grid, the files leave. The window body may run at most
// twice (the mark's arrival and exit), since the mark is an overlay of its own. Nested in BodyCountSuites, as
// every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SuiteKernel
import SwiftUI
import Testing

@testable import LibraryApp
@testable import SuiteShell

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryFileDropTests {
        @Test(.timeLimit(.minutes(2))) func dragHoverInTwoBodies() async throws {
            let hover = SuiteDropHover()
            let drop = SuiteFileDropModifier(
                app: .library, documentName: LibraryWindow.dropTarget, plan: { _ in [] }, perform: { _ in },
                hover: hover)
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "samples"]).modifier(drop))
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
            let photos: [DropAction] = ["beach", "dunes", "pier"].map { .place(path: "/tmp/\($0).jpg") }
            let step = try await w.measure("library file drag hover: mark, 120 moves, leave", bodies: bodies) {
                try await w.ticks(1) { _ in hover.planned(photos, for: hover.begin()) }
                #expect(await w.element(SuiteFileControlID.dropMark) != nil, "the hover shows no mark")
                #expect(w.label(SuiteFileControlID.dropMark) == "Place in Library", "the mark doesn't name Library")
                try await w.ticks(120) { i in w.send(.mouseMoved, at: CGPoint(x: 160 + 8 * i, y: 400)) }
                try await w.ticks(1) { _ in hover.exit() }
            }
            #expect(w.label(SuiteFileControlID.dropMark) == nil, "the mark stayed after the files left")
            // The mark is an overlay: the window renders at most for its arrival and exit. Target: 0.
            expectBodies(step, atMost: 2, target: 0)
        }
    }
}
#endif
