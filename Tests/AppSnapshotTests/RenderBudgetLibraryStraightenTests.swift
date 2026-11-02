// RenderBudgetLibraryStraightenTests.swift: crop's Straighten on the real
// Library window (quality gate #5954, render-contract rules 3 and 6), through
// the harness (RenderBudgetHarness.swift). On the `shoot` fixture it opens the
// first 6000 × 4000 photo in the loupe, picks the Develop tab, clicks the
// photo and presses R (a key-capable window), then steps Straighten
// (`library.crop.straighten`) 120 times at 120 Hz through its adjustable
// action. The loupe turns its unturned picture with a compositor transform,
// so `bodies` gates that the steps start no loupe render
// (`LibraryWindow.loupeRenders`) and caps the window bodies. `timing` gates
// the step p95 on one frame; it is a wall-clock test, so it stays disabled
// until Tests/perf-suites.txt lists it. Nested in BodyCountSuites, as every
// suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryStraightenTests {
        @Test(.timeLimit(.minutes(2))) func bodies() async throws {
            let (step, renders) = try await Self.run()
            // A straighten step is a compositor turn of the picture already drawn. Target: 0.
            #expect(renders == 0, "120 straighten steps started \(renders) loupe renders: \(step)")
            // Each step changes the draft, which the overlay and the CROP section read. Target: 120.
            expectBodies(step, atMost: Self.budget, target: 120)
        }

        @Test(.disabled("a wall-clock gate: waits on its Tests/perf-suites.txt line"), .timeLimit(.minutes(2)))
        func timing() async throws {
            let (step, _) = try await Self.run()
            // One 120 Hz frame is the target; one 60 Hz frame the hard cap (render-contract rule 3).
            expectP95(step, atMost: 16, target: 8)
        }

        /// What this branch measured (Tests/render-budgets.md); it only ratchets down.
        static let budget = 120

        static func run() async throws -> (step: RenderStep, renders: Int) {
            let w = RenderBudgetWindow(
                LibraryWindow(arguments: ["Library", "-LibraryFixture", "shoot"]).allowsWindowActivationEvents(),
                keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            _ = w.window.makeFirstResponder(w.host)
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
            let photo = try #require(await w.element("library.loupe.photo"), "Open showed no loupe photo")
            #expect(w.select(segment: "library.inspector.develop"), "no Develop tab")
            try await w.settle(untilStable: bodies, turns: 8)
            try await w.ticks(1) { _ in w.click(at: CGPoint(x: photo.midX, y: photo.midY)) }
            try await w.settle(200)
            RenderBudgetBrushKeysTests.press("r", in: w.window)
            #expect(await w.element("library.crop.frame") != nil, "R showed no crop frame")
            try await w.settle(untilStable: bodies, turns: 8)
            #if DEBUG
            let before = LibraryWindow.loupeRenders
            #endif
            var adjustable = false
            let step = try await w.measure("library crop straighten, 120 steps, 24 MP", bodies: bodies) {
                adjustable = try await w.adjust("library.crop.straighten", steps: 120)
            }
            try await w.settle(300)
            #expect(adjustable, "Straighten isn't adjustable")
            let angle = w.value("library.crop.straighten") ?? ""
            #expect(!angle.isEmpty && !angle.hasPrefix("0"), "120 steps left Straighten at \(angle)")
            #if DEBUG
            return (step, LibraryWindow.loupeRenders - before)
            #else
            return (step, 0)
            #endif
        }
    }
}
#endif
