// BoxGestureMathKernelTests.swift: AT-f1 of adopt-kernel-transform (#1938). Flare's box handles 0...7 are the
// kernel's `EditorHandle` ring: `BoxGestureMath.handle(_:on:)` reads each spot from the kernel, the Int to
// `EditorHandle` mapping round-trips, and Flare's corner and edge tests agree with `isCorner`.
import FlareCore
import FlareModel
import SuiteKernel
import Testing

private let boxes = [
    Rect(minX: 10, minY: 20, maxX: 110, maxY: 70),
    Rect(minX: -35.5, minY: -12.25, maxX: 4.75, maxY: 90.5),
    Rect(minX: 3, minY: 3, maxX: 3, maxY: 3),
]

/// The kernel's centre for `handle` on `box`: its 0-size square from `BoxMath.handles(of:size:)`.
private func kernelSpot(_ handle: EditorHandle, on box: Rect) throws -> Point {
    let square = try #require(BoxMath.handles(of: box, size: 0)[handle])
    return Point(x: (square.minX + square.maxX) / 2, y: (square.minY + square.maxY) / 2)
}

@Suite struct BoxGestureMathKernelTests {
    @Test(arguments: 0..<8)
    func everyFlareHandleSitsWhereTheKernelPutsIt(_ h: Int) throws {
        let handle = EditorHandle.allCases[h]
        for box in boxes {
            let spot = try kernelSpot(handle, on: box)
            #expect(BoxGestureMath.handle(h, on: box) == spot, "handle \(h) on \(box)")
            #expect(BoxGestureMath.handle(h + 8, on: box) == spot, "handle \(h + 8) wraps to \(h)")
            #expect(BoxGestureMath.handle(h - 8, on: box) == spot, "handle \(h - 8) wraps to \(h)")
            #expect(BoxGestureMath.handle(h - 16, on: box) == spot, "handle \(h - 16) wraps to \(h)")
        }
    }

    @Test(arguments: 0..<8)
    func flareHandlesMapOntoTheKernelRingAndBack(_ h: Int) {
        let handle = EditorHandle.allCases[h]
        #expect(BoxGestureMath.editorHandle(h) == handle)
        #expect(BoxGestureMath.editorHandle(h + 8) == handle)
        #expect(BoxGestureMath.editorHandle(h - 8) == handle)
        #expect(BoxGestureMath.flareHandle(handle) == h)
        // Flare's even handles are the corners, its odd ones the edges.
        #expect(handle.isCorner == (h % 2 == 0))
        // The opposite handle is four steps round the ring.
        #expect(BoxGestureMath.editorHandle(h + 4) == EditorHandle.allCases[(h + 4) % 8])
        #expect(BoxGestureMath.opposite(handle) == EditorHandle.allCases[(h + 4) % 8])
    }

    @Test func theInsideAndTheKnobAreNoFlareHandle() {
        #expect(BoxGestureMath.flareHandle(.inside) == nil)
        #expect(BoxGestureMath.flareHandle(.rotate) == nil)
        #expect(BoxGestureMath.opposite(.inside) == .inside)
        #expect(BoxGestureMath.handle(Int.max, on: boxes[0]) == BoxGestureMath.handle(Int.max % 8, on: boxes[0]))
        #expect(BoxGestureMath.handle(Int.min, on: boxes[0]) == BoxGestureMath.handle(0, on: boxes[0]))
    }

    @Test(arguments: 0..<8)
    func anEdgeHandleMovesOnlyItsOwnAxis(_ h: Int) {
        let handle = EditorHandle.allCases[h]
        #expect(BoxGestureMath.movesOnlyY(handle) == (handle == .top || handle == .bottom))
        #expect(BoxGestureMath.movesOnlyX(handle) == (handle == .left || handle == .right))
        #expect(!(handle.isCorner && (BoxGestureMath.movesOnlyX(handle) || BoxGestureMath.movesOnlyY(handle))))
    }
}
