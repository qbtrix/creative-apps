// RenderBudgetUnsavedGuardTests.swift (adopt-kernel-unsaved-prompt UP-4, quality row "render: Command-W, the
// sheet, Cancel"): what asking costs the window it asks on. The gallery's fake document (UnsavedSheetFixture,
// "Poster", edited) behind `.unsavedChangesGuard` in the harness's 1280 x 820 window, made titled and closable so a
// close reaches the guard's delegate. One measured interaction: a close puts the sheet up and Cancel takes it down.
// The sheet is its own window, so the document's body runs at most twice (the key change the sheet makes and its
// end; target 0), and the window stays open and dirty. Nested in BodyCountSuites: it reads a global body
// counter. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetUnsavedGuardTests {
        @Test(.timeLimit(.minutes(2))) func askAndCancelInTwoBodies() async throws {
            let fixture = UnsavedSheetFixture()
            let w = RenderBudgetWindow(UnsavedSheetDocument().unsavedChangesGuard(fixture.hooks))
            defer { w.close() }
            w.window.styleMask.formUnion([.titled, .closable])
            let bodies = { () -> Int? in
                #if DEBUG
                return UnsavedSheetDocument.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            let step = try await w.measure("unsaved guard: close, the sheet, Cancel", bodies: bodies) {
                try await w.ticks(1) { _ in w.window.performClose(nil) }
                let up = await UnsavedSheetFixture.eventually { w.window.attachedSheet != nil }
                #expect(up, "a close of the dirty document put no sheet up")
                let cancel = UnsavedSheetFixture.button(.cancel, in: w.window)
                #expect(cancel != nil, "the sheet has no Cancel button")
                try await w.ticks(1) { _ in cancel?.performClick(nil) }
                let down = await UnsavedSheetFixture.eventually { w.window.attachedSheet == nil }
                #expect(down, "Cancel left the sheet up")
            }
            #expect(w.window.isVisible, "Cancel closed the window")
            #expect(fixture.dirty, "Cancel saved the document")
            expectBodies(step, atMost: 2, target: 0)
        }
    }
}
#endif
