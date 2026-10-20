// HaloShapeToolTests.swift: shape-tools HS-3 in the real viewer. HaloViewer
// on `three-layers` in the render-budget harness's window, a HaloShapeDrawing
// with the star tool on as its `haloShapeDrawing`, counting what it draws.
// A 120-sample viewer drag shows a draft the whole way and draws once, on the
// release, in the box the Model maps the drag to; a press that Escape cancels
// (the viewer's Escape route, `escape()`, since a test window can't take
// keys) draws nothing and keeps the tool on, and Escape with no drag turns
// it off. A doubled draw fails the count. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct HaloShapeToolTests {
        static let star = ShapeSpec(kind: .star, points: 6, innerRatio: 0.5)
        static let artboard = CGSize(width: 1920, height: 1080)

        /// The viewer hosted with the star tool on; every draw lands in `drawn`.
        static func host(_ drawn: @escaping @MainActor (HaloShapeDrawn) -> Void) async throws
            -> (RenderBudgetWindow<some View>, HaloShapeDrawing, CGRect)
        {
            let project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
            let drawing = HaloShapeDrawing(tool: star, draw: drawn)
            drawing.isOn = true
            let w = RenderBudgetWindow(
                HaloViewer(model: project)
                    .environment(\.haloShapeDrawing, drawing)
                    .environment(\.haloViewerTakesActivationClicks, true))
            try await w.settle(500)
            let canvas = try #require(await w.element("halo.viewer.canvas"), "no halo.viewer.canvas")
            return (w, drawing, canvas)
        }

        @Test(.timeLimit(.minutes(2))) func aViewerDragWithTheToolOnEmitsOneDrawOnReleaseEscapeCancels() async throws {
            var drawn: [HaloShapeDrawn] = []
            let (w, drawing, canvas) = try await Self.host { drawn.append($0) }
            defer { w.close() }
            let start = w.point(CGPoint(x: 760, y: 340), on: Self.artboard, in: canvas)
            let end = w.point(CGPoint(x: 1160, y: 740), on: Self.artboard, in: canvas)
            var drafts = 0
            try await w.drag(from: start, samples: 120, release: false) { i in
                if drawing.draft != nil { drafts += 1 }
                let t = Double(i) / 120
                return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            }
            #expect(drafts >= 100, "the viewer showed no draft while dragging: \(drafts)")
            #expect(drawn.isEmpty, "the drag drew before its release")
            w.timed { w.send(.leftMouseUp, at: end) }
            try await w.settle(100)
            #expect(drawn.count == 1, "one drag drew \(drawn.count) shapes")
            let box = try #require(drawn.first?.box)
            #expect(drawn.first?.spec == Self.star)
            // A point is about 2 composition pixels at this fit; the ends land within a few.
            #expect(abs(box.minX - 760) < 4 && abs(box.minY - 340) < 4 && abs(box.maxX - 1160) < 4 && abs(box.maxY - 740) < 4, "\(box)")
            #expect(drawing.draft == nil)

            // Escape mid-drag: the release draws nothing and the tool stays on.
            try await w.drag(from: start, samples: 12, release: false) { i in CGPoint(x: start.x + Double(i) * 10, y: start.y) }
            drawing.escape()
            w.timed { w.send(.leftMouseUp, at: CGPoint(x: start.x + 120, y: start.y)) }
            try await w.settle(100)
            #expect(drawn.count == 1 && drawing.isOn && drawing.draft == nil, "Escape didn't cancel the drag")
            drawing.escape()
            #expect(drawing.isOn == false, "Escape with no drag left the tool on")
        }
    }
}
#endif
