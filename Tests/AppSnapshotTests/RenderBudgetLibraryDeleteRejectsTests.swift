// RenderBudgetLibraryDeleteRejectsTests.swift: Delete Rejected Photos' render budget (cull-finish DR-4,
// Tests/render-budgets.md). On `large` (10,000 photos) the trash area's DEBUG hooks reject 300, then run
// Move to Trash: one catalog change, at most 3 window bodies (target 1). Until DR-6 the step changes
// nothing. Nested in BodyCountSuites, as every body-counting suite is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryDeleteRejectsTests {
        @Test(.timeLimit(.minutes(2))) func deleteOf300InThreeBodies() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "large"]))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return LibraryWindow.bodyRuns
                #else
                return nil
                #endif
            }
            var hooked = false
            #if DEBUG
            hooked = LibraryTrashArea.rejectHook != nil && LibraryTrashArea.confirmHook != nil
            LibraryTrashArea.rejectHook?(300)
            #endif
            #expect(hooked, "the trash area never set its hooks")
            try await w.settle(untilStable: bodies, turns: 8)
            let step = try await w.measure("library deletes 300 rejects of 10,000", bodies: bodies) {
                try await w.ticks(1) { _ in
                    #if DEBUG
                    LibraryTrashArea.confirmHook?()
                    #endif
                }
            }
            // One catalog change for all 300. Target: 1.
            expectBodies(step, atMost: 3, target: 1)
        }
    }
}
#endif
