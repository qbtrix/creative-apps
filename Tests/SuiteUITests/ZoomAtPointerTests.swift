// ZoomAtPointerTests.swift: a pinch zooms about the pointer. The document
// point under the pointer stays under it (ZoomMath.anchoredOrigin, the one
// place that math lives), at several zooms and pointer spots, corners
// included; a zoom held at a range end moves nothing. CanvasLayout's
// anchoredOffset turns that into the scroll offset CanvasViewport's pinch
// scrolls to, and CanvasHostView's magnify(by:at:) into its pan. macOS only.
import AppKit
import Testing

@testable import SuiteUI

private func close(_ a: CGPoint, _ b: CGPoint, within tolerance: CGFloat = 1e-6) -> Bool {
    abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
}

@Test func anchoredOriginKeepsTheDocumentPointUnderThePointer() {
    let origin = CGPoint(x: 100, y: 50)
    let pointers = [CGPoint(x: 0, y: 0), CGPoint(x: 960, y: 600), CGPoint(x: 960, y: 0), CGPoint(x: 0, y: 600),
                    CGPoint(x: 480, y: 300), CGPoint(x: 133, y: 517)]
    let zooms: [(Double, Double)] = [(1, 2), (2, 1), (0.1, 0.35), (0.5, 8), (8, 32), (3, 0.2)]
    for pointer in pointers {
        for (old, new) in zooms {
            let moved = ZoomMath.anchoredOrigin(pointer: pointer, origin: origin, from: old, to: new)
            let before = CGPoint(x: (pointer.x - origin.x) / old, y: (pointer.y - origin.y) / old)
            let after = CGPoint(x: (pointer.x - moved.x) / new, y: (pointer.y - moved.y) / new)
            #expect(close(before, after), "pointer \(pointer), \(old) -> \(new)")
        }
    }
}

@Test func anchoredOriginDoesNotDriftAtTheClamp() {
    let origin = CGPoint(x: -400, y: 220)
    let pointer = CGPoint(x: 700, y: 30)
    #expect(ZoomMath.anchoredOrigin(pointer: pointer, origin: origin, from: 32, to: 40) == origin)
    #expect(ZoomMath.anchoredOrigin(pointer: pointer, origin: origin, from: 0.1, to: 0.05) == origin)
    // Past the end it stops at the end: the same as zooming to exactly 32.
    #expect(ZoomMath.anchoredOrigin(pointer: pointer, origin: origin, from: 16, to: 64)
        == ZoomMath.anchoredOrigin(pointer: pointer, origin: origin, from: 16, to: 32))
    // A zoom that isn't a number counts as 100%, never a division by zero.
    #expect(ZoomMath.anchoredOrigin(pointer: pointer, origin: origin, from: .nan, to: 1) == origin)
}

@Test func canvasLayoutAnchoredOffsetKeepsTheDocumentPointUnderThePointer() {
    let document = CGSize(width: 1000, height: 1000)
    let viewport = CGSize(width: 800, height: 600)
    let old = CanvasLayout(document: document, zoom: 2, viewport: viewport, margin: 32)
    let scrolled = CGPoint(x: 300, y: 200)
    for pointer in [CGPoint(x: 100, y: 400), CGPoint(x: 700, y: 50), CGPoint(x: 400, y: 300)] {
        let next = CanvasLayout(document: document, zoom: 3, viewport: viewport, margin: 32)
        let offset = old.anchoredOffset(to: next, pointer: pointer, scrolled: scrolled)
        let before = old.documentPoint(CGPoint(x: pointer.x + scrolled.x, y: pointer.y + scrolled.y))
        let after = next.documentPoint(CGPoint(x: pointer.x + offset.x, y: pointer.y + offset.y))
        #expect(close(before, after), "pointer \(pointer)")
    }
    // The same zoom (held at the clamp) leaves the scroll where it was.
    let held = CanvasLayout(document: document, zoom: 2, viewport: viewport, margin: 32)
    #expect(old.anchoredOffset(to: held, pointer: CGPoint(x: 10, y: 590), scrolled: scrolled) == scrolled)
}

@MainActor
@Suite struct CanvasHostZoomAtPointerTests {
    struct Content: CanvasContentProviding {
        var documentSize: CGSize { CGSize(width: 400, height: 300) }
        func tiles(dirtyOnly: Bool) -> [CanvasTile] { [] }
    }

    private func canvas() -> CanvasHostView {
        let canvas = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 960, height: 600))
        canvas.show(Content())
        return canvas
    }

    @Test func aPinchKeepsTheDocumentPointUnderThePointer() {
        let canvas = canvas()
        let board = canvas.artboard
        let pointers = [CGPoint(x: board.minX + 20, y: board.maxY - 15), CGPoint(x: board.maxX - 5, y: board.minY + 5),
                        CGPoint(x: 0, y: 0), CGPoint(x: 960, y: 600)]
        for pointer in pointers {
            for factor: CGFloat in [1.5, 1.2, 0.4, 3] {
                let before = canvas.documentPoint(pointer)
                canvas.magnify(by: factor, at: pointer)
                #expect(close(canvas.documentPoint(pointer), before, within: 1e-3), "pointer \(pointer) x\(factor)")
            }
        }
    }

    @Test func aPinchHeldAtTheClampDoesNotPan() {
        let canvas = canvas()
        let pointer = CGPoint(x: canvas.artboard.minX + 30, y: canvas.artboard.minY + 40)
        canvas.magnify(by: 1000, at: pointer)
        #expect(canvas.zoom == 32)
        let pan = canvas.pan
        canvas.magnify(by: 1.1, at: pointer)
        #expect(canvas.pan == pan)
        canvas.magnify(by: 0.0001, at: pointer)
        #expect(canvas.zoom == CGFloat(0.1))
        let low = canvas.pan
        canvas.magnify(by: 0.5, at: pointer)
        #expect(canvas.pan == low)
    }
}
