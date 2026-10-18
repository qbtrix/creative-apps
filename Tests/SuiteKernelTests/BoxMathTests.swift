// BoxMathTests.swift (editor-kernel EK-19, slice EK-box, KJ6): the selection
// box's resize, scale and rotate math. Written against the EK-3 stubs and
// disabled until EK-20 gives BoxMath its body. Document y grows downwards.
import Foundation
import Testing
import SuiteKernel

@Suite struct BoxMathTests {
    let box = Rect(minX: 10, minY: 20, maxX: 110, maxY: 70)
    let wide = Rect(minX: 0, minY: 0, maxX: 100, maxY: 50)

    @Test(.disabled("waits on EK-20")) func eachHandleMovesItsEdges() {
        let delta = Point(x: 5, y: 7)
        let expected: [(EditorHandle, Rect)] = [
            (.topLeft, Rect(minX: 15, minY: 27, maxX: 110, maxY: 70)),
            (.top, Rect(minX: 10, minY: 27, maxX: 110, maxY: 70)),
            (.topRight, Rect(minX: 10, minY: 27, maxX: 115, maxY: 70)),
            (.right, Rect(minX: 10, minY: 20, maxX: 115, maxY: 70)),
            (.bottomRight, Rect(minX: 10, minY: 20, maxX: 115, maxY: 77)),
            (.bottom, Rect(minX: 10, minY: 20, maxX: 110, maxY: 77)),
            (.bottomLeft, Rect(minX: 15, minY: 20, maxX: 110, maxY: 77)),
            (.left, Rect(minX: 15, minY: 20, maxX: 110, maxY: 70)),
        ]
        for (handle, rect) in expected {
            #expect(BoxMath.resized(box, handle, by: delta, modifiers: []) == rect, "\(handle)")
        }
    }

    @Test(.disabled("waits on EK-20")) func shiftKeepsAspect() {
        // The larger change (y) wins and x follows at the 2:1 aspect.
        #expect(BoxMath.resized(wide, .bottomRight, by: Point(x: 10, y: 20), modifiers: .shift)
            == Rect(minX: 0, minY: 0, maxX: 140, maxY: 70))
        // The larger change (x) wins and y follows.
        #expect(BoxMath.resized(wide, .bottomRight, by: Point(x: 40, y: 5), modifiers: .shift)
            == Rect(minX: 0, minY: 0, maxX: 140, maxY: 70))
        // A top-left drag keeps the bottom-right corner fixed.
        #expect(BoxMath.resized(wide, .topLeft, by: Point(x: -40, y: -5), modifiers: .shift)
            == Rect(minX: -40, minY: -20, maxX: 100, maxY: 50))
        // Without Shift the same drag does not keep the aspect.
        #expect(BoxMath.resized(wide, .bottomRight, by: Point(x: 40, y: 5), modifiers: [])
            == Rect(minX: 0, minY: 0, maxX: 140, maxY: 55))
    }

    @Test(.disabled("waits on EK-20")) func optionResizesFromCentre() {
        #expect(BoxMath.resized(wide, .right, by: Point(x: 10, y: 0), modifiers: .option)
            == Rect(minX: -10, minY: 0, maxX: 110, maxY: 50))
        #expect(BoxMath.resized(wide, .bottomRight, by: Point(x: 10, y: 6), modifiers: .option)
            == Rect(minX: -10, minY: -6, maxX: 110, maxY: 56))
        #expect(BoxMath.resized(wide, .top, by: Point(x: 0, y: 5), modifiers: .option)
            == Rect(minX: 0, minY: 5, maxX: 100, maxY: 45))
        // Shift and Option together: the aspect is kept about the centre.
        #expect(BoxMath.resized(wide, .bottomRight, by: Point(x: 20, y: 0), modifiers: [.shift, .option])
            == Rect(minX: -20, minY: -10, maxX: 120, maxY: 60))
    }

    @Test(.disabled("waits on EK-20")) func minimumOnePoint() {
        #expect(BoxMath.resized(wide, .right, by: Point(x: -200, y: 0), modifiers: [])
            == Rect(minX: 0, minY: 0, maxX: 1, maxY: 50))
        #expect(BoxMath.resized(wide, .bottom, by: Point(x: 0, y: -100), modifiers: [])
            == Rect(minX: 0, minY: 0, maxX: 100, maxY: 1))
        #expect(BoxMath.resized(wide, .bottomRight, by: Point(x: -100, y: -50), modifiers: [])
            == Rect(minX: 0, minY: 0, maxX: 1, maxY: 1))
    }

    @Test(.disabled("waits on EK-20")) func neverFlipsPastTheFixedEdge() {
        #expect(BoxMath.resized(wide, .left, by: Point(x: 500, y: 0), modifiers: [])
            == Rect(minX: 99, minY: 0, maxX: 100, maxY: 50))
        #expect(BoxMath.resized(wide, .topLeft, by: Point(x: 300, y: 300), modifiers: [])
            == Rect(minX: 99, minY: 49, maxX: 100, maxY: 50))
        let all: [EditModifiers] = [[], .shift, .option, [.shift, .option]]
        for handle in EditorHandle.allCases where handle != .inside && handle != .rotate {
            for mods in all {
                for delta in [Point(x: 400, y: -400), Point(x: -400, y: 400), Point(x: 400, y: 400)] {
                    let r = BoxMath.resized(wide, handle, by: delta, modifiers: mods)
                    #expect(r.width >= 1 && r.height >= 1, "\(handle) \(mods.rawValue) \(delta)")
                }
            }
        }
    }

    @Test(.disabled("waits on EK-20")) func worksOnAScaledBox() {
        // A box already scaled to fractional points keeps its 2:1 aspect with Shift.
        let scaled = Rect(minX: 2.5, minY: 1.25, maxX: 52.5, maxY: 26.25)
        let r = BoxMath.resized(scaled, .bottomRight, by: Point(x: 25, y: 2), modifiers: .shift)
        #expect(r == Rect(minX: 2.5, minY: 1.25, maxX: 77.5, maxY: 38.75))
        #expect(abs(r.width / r.height - 2) < 1e-9)
    }

    @Test(.disabled("waits on EK-20")) func severalScaleAsOneBox() {
        let union = Rect(minX: 0, minY: 0, maxX: 200, maxY: 100)
        let a = Rect(minX: 0, minY: 0, maxX: 100, maxY: 50)
        let b = Rect(minX: 100, minY: 50, maxX: 200, maxY: 100)
        let wider = Rect(minX: 0, minY: 0, maxX: 400, maxY: 50)
        #expect(BoxMath.scaled(a, from: union, to: wider) == Rect(minX: 0, minY: 0, maxX: 200, maxY: 25))
        #expect(BoxMath.scaled(b, from: union, to: wider) == Rect(minX: 200, minY: 25, maxX: 400, maxY: 50))
        let moved = Rect(minX: 100, minY: 100, maxX: 300, maxY: 200)
        #expect(BoxMath.scaled(a, from: union, to: moved) == Rect(minX: 100, minY: 100, maxX: 200, maxY: 150))
        #expect(BoxMath.scaled(union, from: union, to: wider) == wider)
    }

    @Test(.disabled("waits on EK-20")) func shiftSnapsRotationTo15Degrees() {
        #expect(BoxMath.snappedDegrees(22, modifiers: .shift) == 15)
        #expect(BoxMath.snappedDegrees(23, modifiers: .shift) == 30)
        #expect(BoxMath.snappedDegrees(-10, modifiers: .shift) == -15)
        #expect(BoxMath.snappedDegrees(90, modifiers: .shift) == 90)
        #expect(BoxMath.snappedDegrees(22, modifiers: []) == 22)
        #expect(BoxMath.snappedDegrees(22, modifiers: .option) == 22)
    }

    @Test(.disabled("waits on EK-20")) func handlesSitOnTheBox() {
        let handles = BoxMath.handles(of: box, size: 8)
        #expect(handles.count == 9 && handles[.inside] == nil && handles[.rotate] != nil)
        #expect(handles[.topLeft] == Rect(minX: 6, minY: 16, maxX: 14, maxY: 24))
        #expect(handles[.bottomRight] == Rect(minX: 106, minY: 66, maxX: 114, maxY: 74))
        #expect(handles[.right] == Rect(minX: 106, minY: 41, maxX: 114, maxY: 49))
        for square in handles.values {
            #expect(square.width == 8 && square.height == 8)
        }
    }
}
