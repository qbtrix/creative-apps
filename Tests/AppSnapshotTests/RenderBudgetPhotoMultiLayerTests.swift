// RenderBudgetPhotoMultiLayerTests.swift (multi-layer-select PM-7, quality
// rows "render: Shift-click a 50-row range in the 100-layer stress list" and
// "render: ⌥⌘A on the 100-layer stress document"): the real Photo window on a
// 100-layer 3840 x 2160 document, hosted on the render budget harness
// (RenderBudgetHarness.swift).
// - A Shift-click from row 1 to row 50 runs PhotoEditor's body (the window
//   body, a debug-only counter) at most 3 times (target 1) and leaves the
//   window's selection what the model's own `pickLayer` makes of the same
//   two picks, so the test holds before and after PM-4 fills in the range.
// - Select > All Layers picks all 100 in at most 1 body (target 1).
// The p95s (packet: ≤ 8 ms and ≤ 16 ms) are printed, not gated: a step-time
// budget belongs in a Tests/perf-suites.txt test, which only the supervisor
// lists. The harness's clicks carry no modifier flags and the menu bar isn't
// hosted, so both gestures go through the window's intent hook as the row
// click and the menu item send them (`.pickLayer(id, .extend)`,
// `.selectAllLayers`), as RenderBudgetPhotoHistoryTests sends `.history`.
// The document stands in for the `stress` fixture until it lands (#3499).
// Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import CoreRaster
import PhotoModel
import SuiteKernel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoMultiLayerTests {
        static let layerCount = 100
        static let range = 50

        @Test(.timeLimit(.minutes(2))) func rangeClickInThreeBodies() async throws {
            let model = try Self.document()
            let ids = model.layers.map(\.id)
            #expect(ids.count == Self.layerCount)
            let w = RenderBudgetWindow(PhotoWindow(model: model))
            defer { w.close() }
            let bodies = { BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)
            let anchor = try #require(ids.first), end = ids[Self.range - 1]
            send(.pickLayer(anchor, .replace))
            try await w.settle(untilStable: bodies)

            let step = try await w.measure("photo layers Shift-click \(Self.range)-row range, 100 layers", bodies: bodies) {
                try await w.ticks(1) { _ in send(.pickLayer(end, .extend)) }
            }
            var expected = model
            expected.pickLayer(anchor, .replace)
            expected.pickLayer(end, .extend)
            #expect(edited.workspace?.selectedLayerIDs == expected.selectedLayerIDs)
            expectBodies(step, atMost: 3, target: 1)
            print("RENDER-BUDGET photo layers range click p95 \(String(format: "%.2f", step.p95)) ms (budget 8, target 8)")
        }

        @Test(.timeLimit(.minutes(2))) func selectAllInOneBody() async throws {
            let w = RenderBudgetWindow(PhotoWindow(model: try Self.document()))
            defer { w.close() }
            let bodies = { BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)

            let step = try await w.measure("photo Select All Layers, 100 layers", bodies: bodies) {
                try await w.ticks(1) { _ in send(.selectAllLayers) }
            }
            #expect(edited.workspace?.selectedLayerIDs.count == Self.layerCount)
            expectBodies(step, atMost: 1, target: 1)
            print("RENDER-BUDGET photo select all layers p95 \(String(format: "%.2f", step.p95)) ms (budget 16, target 16)")
        }

        /// A 3840 x 2160 canvas with `layerCount` layers: the `stress` fixture's shape (#3499).
        static func document() throws -> PhotoWorkspace {
            var model = PhotoWorkspace()
            try model.newCanvas(width: 3840, height: 2160)
            while model.layers.count < layerCount { model.addLayer() }
            return model
        }
    }
}

#endif
