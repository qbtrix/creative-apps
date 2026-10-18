// PhotoKernelTransformTests.swift: Photo's live transform runs on SuiteKernel
// (adopt-kernel-transform AT-p1). Its handle hit is HandleHit's answer, a
// side or corner drag is BoxMath.resized with Shift and Option forwarded, a
// rotate drag snaps through BoxMath.snappedDegrees, and applying or flipping
// still refuses as PV-7. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import CoreRaster
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoKernelTransformTests {
    private let live = PhotoServices.live.transform
    private let draft = TransformDraft(layerID: "layer-1", box: PixelRect(x: 10, y: 20, width: 100, height: 50))
    private let rect = Rect(minX: 10, minY: 20, maxX: 110, maxY: 70)

    private func point(_ x: Double, _ y: Double) -> Mask.Point { Mask.Point(x: x, y: y) }

    @Test func theContractTypesAreTheKernels() {
        #expect(ObjectIdentifier(TransformHandle.self) == ObjectIdentifier(EditorHandle.self))
        #expect(ObjectIdentifier(PhotoModel.LayerTransform.self) == ObjectIdentifier(SuiteKernel.LayerTransform.self))
        #expect(TransformHandle.allCases == [.topLeft, .top, .topRight, .right, .bottomRight, .bottom, .bottomLeft,
                                             .left, .inside, .rotate])
    }

    @Test func theHandleHitIsHandleHitsAnswer() {
        let probes: [(Double, Double)] = [
            (10, 20), (60, 20), (110, 20), (110, 45), (110, 70), (60, 70), (10, 70), (10, 45),
            (60, 45), (30, 60), (300, 300), (13, 22), (108, 67), (5, 45), (60, 74),
        ]
        for tolerance in [2.0, 4.0, 6.0] {
            for (x, y) in probes {
                let expected = HandleHit.handle(at: Point(x: x, y: y), in: rect, tolerance: tolerance)
                #expect(live.handle(at: point(x, y), in: draft, tolerance: tolerance) == expected, "\(x),\(y) ±\(tolerance)")
            }
        }
        #expect(live.handle(at: point(110, 20), in: draft, tolerance: 4) == .topRight)
        #expect(live.handle(at: point(13, 22), in: draft, tolerance: 4) == .topLeft)
        #expect(live.handle(at: point(13, 22), in: draft, tolerance: 2) == .inside)
        #expect(live.handle(at: point(300, 300), in: draft, tolerance: 6) == nil)
    }

    /// The draft's transform after `rect` became `resized`.
    private func expectTransform(_ moved: TransformDraft, is resized: Rect) {
        #expect(abs(moved.transform.scaleX - resized.width / 100) < 1e-9)
        #expect(abs(moved.transform.scaleY - resized.height / 50) < 1e-9)
        #expect(abs(moved.transform.dx - (resized.minX - 10)) < 1e-9)
        #expect(abs(moved.transform.dy - (resized.minY - 20)) < 1e-9)
    }

    @Test func aPlainCornerDragIsBoxMathResized() {
        let moved = live.dragged(draft, handle: .bottomRight, from: point(110, 70), to: point(130, 75), modifiers: [])
        expectTransform(moved, is: BoxMath.resized(rect, .bottomRight, by: Point(x: 20, y: 5), modifiers: []))
        #expect(moved.transform.scaleX != moved.transform.scaleY)
    }

    @Test func shiftKeepsTheAspect() {
        let moved = live.dragged(draft, handle: .bottomRight, from: point(110, 70), to: point(130, 75), modifiers: [.shift])
        expectTransform(moved, is: BoxMath.resized(rect, .bottomRight, by: Point(x: 20, y: 5), modifiers: [.shift]))
        #expect(abs(moved.transform.scaleX - moved.transform.scaleY) < 1e-9)
        #expect(abs(moved.transform.scaleX - 1.2) < 1e-9)
    }

    @Test func optionMirrorsAboutTheCentre() {
        let moved = live.dragged(draft, handle: .bottomRight, from: point(110, 70), to: point(130, 75), modifiers: [.option])
        expectTransform(moved, is: BoxMath.resized(rect, .bottomRight, by: Point(x: 20, y: 5), modifiers: [.option]))
        let corners = live.corners(of: moved)
        #expect(corners.count == 4)
        let cx = corners.map(\.x).reduce(0, +) / 4, cy = corners.map(\.y).reduce(0, +) / 4
        #expect(abs(cx - 60) < 1e-9 && abs(cy - 45) < 1e-9)
    }

    @Test func anEdgeDragMovesOneSide() {
        let moved = live.dragged(draft, handle: .left, from: point(10, 45), to: point(0, 90), modifiers: [])
        expectTransform(moved, is: BoxMath.resized(rect, .left, by: Point(x: -10, y: 45), modifiers: []))
        #expect(abs(moved.transform.scaleY - 1) < 1e-9)
    }

    @Test func insideMovesTheBox() {
        let moved = live.dragged(draft, handle: .inside, from: point(50, 40), to: point(57, 43), modifiers: [.shift])
        #expect(moved.transform == PhotoModel.LayerTransform(dx: 7, dy: 3))
        let corners = live.corners(of: moved)
        #expect(corners.map(\.x) == [17, 117, 117, 17] && corners.map(\.y) == [23, 23, 73, 73])
    }

    @Test func cornersStartAtTheBox() {
        let corners = live.corners(of: draft)
        #expect(corners.map(\.x) == [10, 110, 110, 10] && corners.map(\.y) == [20, 20, 70, 70])
    }

    @Test func rotateTurnsAndShiftSnapsToFifteen() {
        // From straight above the centre (60, 45) to 20 degrees clockwise of it.
        let turn = 20.0 * Double.pi / 180
        let end = point(60 + 45 * sin(turn), 45 - 45 * cos(turn))
        let free = live.dragged(draft, handle: .rotate, from: point(60, 0), to: end, modifiers: [])
        #expect(abs(free.transform.degrees - 20) < 1e-9)
        let snapped = live.dragged(draft, handle: .rotate, from: point(60, 0), to: end, modifiers: [.shift])
        #expect(snapped.transform.degrees == BoxMath.snappedDegrees(free.transform.degrees, modifiers: .shift))
        #expect(snapped.transform.degrees == 15)
        #expect(snapped.transform.scaleX == 1 && snapped.transform.dx == 0)
    }

    @Test func applyingAndFlippingStillRefuseAsPV7() throws {
        let pixels = try FakeMasking().mask(from: nil, layerBounds: PixelRect(x: 0, y: 0, width: 2, height: 2))
        let content = PlacedPixels(pixels: pixels, x: 0, y: 0)
        let refusal = PhotoRefusal("Not built yet (PV-7).")
        #expect(live.unavailableHelp == refusal.message)
        #expect(throws: refusal) { try live.applied(draft, to: content) }
        #expect(throws: refusal) { try live.flipped(content, .horizontal) }
        #expect(throws: refusal) { try live.flipped(content, .vertical) }
    }
}
