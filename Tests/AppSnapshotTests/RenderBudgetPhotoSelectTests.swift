// RenderBudgetPhotoSelectTests.swift: the Select tool on the real Photo window does no work while the pointer is
// down (#6012). It hosts PhotoWindow on a 24 MP image (6000 x 4000: an opaque background under a layer painted
// only near its top-left) and sends the window's drag intents: a click on the background, then a 120-sample box
// drag from off the canvas (the background is opaque, so a press on it would move it). The click runs on the live
// transform (a press on a layer is a move that went nowhere), the box's whole gesture, its press too, on
// LiveDragLine's copy, so with the pointer down the editor body runs 0 times and the canvas composites 0 regions
// (PhotoRenderCount, debug only); the box shows on the overlay. The release picks: the click the background, the
// box both layers. The counts start once the first picture has landed (`idle` must settle; it can take over a
// minute on a loaded runner). Nested in BodyCountSuites: it reads process-wide counters. macOS only.
#if canImport(AppKit)
import AppKit
import CoreRaster
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoSelectTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(3))) func selectClickAndBoxRunNoBodyAndNoPixelWorkWhileDown() async throws {
            let (model, top, bottom) = try Self.document(.select)
            let w = RenderBudgetWindow(PhotoWindow(model: model).allowsWindowActivationEvents())
            defer { w.close() }
            let (opened, regions) = (ContinuousClock.now, Self.regions())
            let (edited, send) = try await Self.open(w)
            print("RENDER-BUDGET photo select open, 24 MP: \(ContinuousClock.now - opened), \(Self.regions() - regions) regions")

            // A click on the background, where the top layer is clear.
            var down = try await Self.whileDown(w) {
                send(.drag(CGPoint(x: 3000, y: 2000), CGPoint(x: 3000, y: 2000)))
            }
            send(.endDrag)
            let clicked = try #require(await RenderBudgetPhotoTransformTests.landed(edited) { $0.selectedLayerIDs == [bottom] })
            #expect(clicked.selectedLayerIDs == [bottom])
            print("RENDER-BUDGET photo select click, 24 MP: \(down.bodies) editor bodies, \(down.regions) regions with the pointer down")
            #if DEBUG
            #expect(down.bodies == 0, "a Select press ran the editor body \(down.bodies) times")
            #expect(down.regions == 0, "a Select press composited \(down.regions) regions")
            #endif

            // A box from off the corner across both layers, one sample per tick.
            down = try await Self.whileDown(w) {
                send(.drag(CGPoint(x: -20, y: -10), CGPoint(x: -20, y: -10)))
                for i in 1...Self.samples {
                    let (a, b) = (Double(i - 1) * 10 - 20, Double(i) * 10 - 20)
                    send(.drag(CGPoint(x: a, y: a / 2), CGPoint(x: b, y: b / 2)))
                }
            }
            let shown = try await Self.boxShown(w)
            send(.endDrag)
            let boxed = try #require(await RenderBudgetPhotoTransformTests.landed(edited) { $0.selectedLayerIDs.count == 2 })
            #expect(boxed.selectedLayerIDs == [top, bottom])
            #expect(boxed.layers.map(\.offsetX) == model.layers.map(\.offsetX), "Select moved a layer")
            #expect(shown, "the box never showed while the pointer was down")
            print("RENDER-BUDGET photo select box, 24 MP, \(Self.samples) samples: \(down.bodies) editor bodies, \(down.regions) regions with the pointer down")
            #if DEBUG
            #expect(down.bodies == 0, "the box drag ran the editor body \(down.bodies) times over \(Self.samples) samples")
            #expect(down.regions == 0, "the box drag composited \(down.regions) regions")
            #endif
        }

        /// The 24 MP image with `tool` picked and the clear top layer selected: a background, and a top layer
        /// painted only near (50, 50).
        static func document(_ tool: PhotoTool) throws -> (PhotoWorkspace, top: String, bottom: String) {
            var model = PhotoWorkspace()
            try model.newImage(DocumentSetup(width: 6000, height: 4000))
            let bottom = try #require(model.selectedLayerID)
            model.addLayer()
            let top = try #require(model.selectedLayerID)
            model.selectTool(.brush)
            model.drag(from: Mask.Point(x: 50, y: 50), to: Mask.Point(x: 60, y: 50))
            model.endDrag()
            model.selectTool(tool)
            return (model, top, bottom)
        }

        static func open<V: View>(_ w: RenderBudgetWindow<V>) async throws -> (PhotoWindowEditedView, PhotoPerform) {
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            try await w.settle(untilStable: RenderBudgetPhotoTransformTests.bodies)
            // The first 24 MP picture runs past a minute on a loaded runner; a press measured before it lands
            // counts its last regions as the press's, so the counts start only from a settled canvas.
            try #require(await RenderBudgetPhotoLiveTransformTests.idle(w, limit: .seconds(150)), "the first picture never landed")
            return (edited, try #require(edited.send))
        }

        /// The editor bodies and composited regions `press` and the settle after it cost, the pointer still down.
        static func whileDown<V: View>(_ w: RenderBudgetWindow<V>, _ press: () -> Void) async throws -> (bodies: Int, regions: Int) {
            let bodies = RenderBudgetPhotoTransformTests.bodies() ?? 0, regions = Self.regions()
            press()
            try await w.settle(200)
            return ((RenderBudgetPhotoTransformTests.bodies() ?? 0) - bodies, Self.regions() - regions)
        }

        static func regions() -> Int {
            #if DEBUG
            return PhotoRenderCount.regions.withLock { $0 }
            #else
            return 0
            #endif
        }

        /// Whether the canvas shows the Select box now.
        static func boxShown<V: View>(_ w: RenderBudgetWindow<V>) async throws -> Bool {
            await w.element("photo.canvas.select-box") != nil
        }
    }
}
#endif
