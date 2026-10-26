// RenderBudgetPhotoLayerStyleTests.swift (layer-styles PY-3, quality row "render: a Distance scrub with the panel
// over the canvas"): the real Photo window on the `layered` fixture, hosted on the render budget harness
// (RenderBudgetHarness.swift), Layer Style… open on Drop Shadow and the shadow on. A 120-sample Distance scrub, one
// sample per 1/120 s from 1/6 px to 20 px under one drag token (one undo step), runs PhotoEditor's body (the window
// body, a debug-only counter) at most 3 times in all (target 1), and leaves the shadow at 20 px. The p95 (packet:
// ≤ 8 ms) is printed, not gated: a step-time budget belongs in a Tests/perf-suites.txt test, which only the
// supervisor lists. The panel's rows have no Distance slider until LS-3 and the sheet is its own window, so the scrub
// goes through the window's intent hook as the slider sends it (`.style(.panel(.set(.dropShadow, …, drag:)))`), as
// RenderBudgetPhotoMultiLayerTests sends `.pickLayer`. Disabled until LS-6: every `style.*` command throws
// `notBuilt` today, so the window shows a problem instead of a shadow.
// Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteImaging
import SuiteKernel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoLayerStyleTests {
        static let samples = 120
        static let distance = 20.0

        @Test(.disabled("waits on LS-6: style.set throws notBuilt"), .timeLimit(.minutes(2)))
        func distanceScrubInThreeBodies() async throws {
            let w = RenderBudgetWindow(PhotoWindow(model: try PhotoWorkspace.fixture(.layered)))
            defer { w.close() }
            let bodies = { BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)
            send(.style(.panel(.show(.dropShadow))))
            send(.style(.panel(.toggle(.dropShadow, true))))
            try await w.settle(untilStable: bodies)
            #expect(edited.workspace?.stylePanel == .dropShadow)
            #expect(edited.workspace?.styleSelection?.effect(.dropShadow)?.isEnabled == true)

            let step = try await w.measure("photo layer style Distance scrub, \(Self.samples) samples", bodies: bodies) {
                try await w.ticks(Self.samples) { i in
                    let distance = Self.distance * Double(i) / Double(Self.samples)
                    send(.style(.panel(.set(.dropShadow, .object(["distance": .number(distance)]), drag: "distance"))))
                }
            }
            let shadow = edited.workspace?.styleSelection?.effect(.dropShadow)?.parameters
            if case .shadow(let value)? = shadow {
                #expect(abs(value.distance - Self.distance) < 0.001)
            } else {
                Issue.record("the selected layer has no drop shadow after the scrub")
            }
            #expect(edited.workspace?.stylePanel == .dropShadow)
            expectBodies(step, atMost: 3, target: 1)
            print("RENDER-BUDGET photo layer style Distance scrub p95 \(String(format: "%.2f", step.p95)) ms (budget 8, target 8)")
        }
    }
}

#endif
