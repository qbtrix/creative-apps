// RenderBudgetPhotoPlaceTests.swift (place-image PP-4, quality row "render: placing a 4000 x 3000 JPEG on a
// live canvas"): what one File > Place… costs the real Photo window, on the render budget harness
// (RenderBudgetHarness.swift). It hosts PhotoWindow on an 800 x 600 white image and sends it the place the menu
// and the drop send (`.place(.drop([.place(path:)]))`, PhotoPlace.swift) with a 4000 x 3000 JPEG, encoded and
// written to a temp file before the measure. PhotoEditor's body (a debug-only counter) runs at most 3 times for it
// (target 1: the new layer). The window's workspace holds one new layer, centred, as one step. The step time is
// printed, not gated: a timing budget belongs in a Tests/perf-suites.txt test, which only the supervisor lists.
// Listed in Tests/heavy-suites.txt: the size is the point.
// Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoPlaceTests {
        // The wait is core's debug-build JPEG decode (about 72 s), qbtrix/creative-core#810; the body budget is the gate.
        @Test(.timeLimit(.minutes(5))) func placeLargeInThreeBodies() async throws {
            var open = PhotoWorkspace()
            try open.newCanvas(width: 800, height: 600)
            let jpeg = try JPEG.write(try PixelBuffer(width: 4000, height: 3000, fill: RGBA(r: 0.2, g: 0.4, b: 0.8, a: 1)))
            let w = RenderBudgetWindow(PhotoWindow(model: open))
            defer { w.close() }
            let bodies = { () -> Int? in BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(1000)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("RenderBudgetPhotoPlace-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let path = folder.appendingPathComponent("photo-4000x3000.jpg").path
            try jpeg.write(to: URL(fileURLWithPath: path))

            let step = try await w.measure("photo place 4000 x 3000 JPEG on 800 x 600", bodies: bodies) {
                w.timed { send(.place(.drop([.place(path: path)]))) }
                try await w.settle(500)
            }
            print("RENDER-BUDGET photo place 4000x3000 JPEG step \(String(format: "%.2f", step.p95)) ms (print-only)")
            let after = try #require(edited.workspace)
            #expect(after.layers.count == 2, "the place added \(after.layers.count - 1) layers, not 1")
            #expect(after.canUndo, "the place made no undo step")
            expectBodies(step, atMost: 3, target: 1)
        }
    }
}
#endif
