// RenderBudgetLibraryVibranceTests.swift: the loupe's real-time slider (quality gate #5953) on the real window,
// through the harness (RenderBudgetHarness.swift). On the `shoot` fixture it opens the first 24 MP photo in the
// loupe with the cell's "Open" action, switches to Develop and steps Vibrance 120 times at 120 Hz through the
// row's adjustable action. Vibrance is core's `.color` family, which the loupe now draws on the GPU route in one
// display pass, so a step runs no CPU develop: in release its p95 is gated at 16 ms (target 8 ms); debug only
// prints it. Nested in BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryVibranceTests {
        @Test(.timeLimit(.minutes(2))) func vibranceStepsInRealTime() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "shoot"]))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return LibraryWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies, turns: 8)
            let first = try #require(w.identifiers().first { $0.hasPrefix(LibraryGrid.cellIdentifierPrefix) })
            #expect(w.perform("Open", on: first), "no Open action on \(first)")
            try await w.settle(500)
            #expect(w.select(segment: "library.inspector.develop"), "no Develop tab")
            try await w.settle(untilStable: bodies, turns: 8)
            let id = DevelopInspector.rowID(.vibrance)
            #expect(await w.element(id) != nil, "no Vibrance row")
            var adjustable = false
            let steps = try await w.measure("library loupe vibrance, 24 MP, 120 steps", bodies: bodies) {
                adjustable = try await w.adjust(id, steps: 120)
            }
            #expect(adjustable, "Vibrance isn't adjustable")
            #expect(steps.layouts > 0, "the steps changed nothing: \(steps)")
            #if !DEBUG
            expectP95(steps, atMost: 16, target: 8)
            #endif
        }
    }
}
#endif
