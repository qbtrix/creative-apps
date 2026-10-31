// DesignSelectToolTests.swift: Design's pointer tool (V) on SuiteKernel's shared Select rule (#6012): the adapter's
// hits, a click picks the layer under it, Shift toggles, an empty click deselects, a box picks what it touches (Shift
// joins), the Layers list's selection is the same state, and no pick is an undo step.
@testable import DesignModel
import SuiteKernel
import Testing

struct DesignSelectToolTests {
    /// The cards fixture: rectangles A (node-2) and B (node-3) inside the Desktop frame, and a press point on each.
    static func board() -> (DesignWorkspace, a: String, b: String, pa: Point, pb: Point) {
        (DesignFixtures.cards, "node-2", "node-3", Point(x: 150, y: 140), Point(x: 400, y: 180))
    }

    @Test func clickPicksShiftTogglesEmptyDeselects() throws {
        var (w, a, b, pa, pb) = Self.board()
        let undo = w.undoActionName
        #expect(SelectTool.release(&w, from: pa, to: pa, extending: false))
        #expect(w.selectedNodeIDs == [a])
        SelectTool.release(&w, from: pb, to: pb, extending: true)
        #expect(w.selectedNodeIDs == [a, b])
        SelectTool.release(&w, from: pb, to: pb, extending: true)
        #expect(w.selectedNodeIDs == [a])
        let empty = Point(x: -5_000, y: -5_000)
        SelectTool.release(&w, from: empty, to: empty, extending: false)
        #expect(w.selectedNodeIDs.isEmpty)
        #expect(w.undoActionName == undo, "a pick is not an undo step")
    }

    @Test func boxPicksWhatItTouchesAndShiftJoins() {
        var (w, a, b, _, _) = Self.board()
        SelectTool.release(&w, from: Point(x: 80, y: 80), to: Point(x: 220, y: 200), extending: false)
        #expect(w.selectedNodeIDs == [a])
        SelectTool.release(&w, from: Point(x: 280, y: 120), to: Point(x: 520, y: 240), extending: true)
        #expect(w.selectedNodeIDs == [a, b])
        SelectTool.release(&w, from: Point(x: 80, y: 80), to: Point(x: 520, y: 240), extending: false)
        #expect(w.selectedNodeIDs == [a, b], "the same layers Move's marquee picks there")
    }

    /// The pointer tool's Shift-click runs the same kernel toggle.
    @Test func moveToolShiftClickTogglesThroughTheKernel() throws {
        var (w, a, b, pa, pb) = Self.board()
        w.selectTool(.move)
        let frames = w.selectedPage?.nodes.map(\.frame)
        for (p, mods) in [(pa, DesignModifiers()), (pb, .shift)] {
            w.drag(from: DesignPoint(x: p.x, y: p.y), to: DesignPoint(x: p.x, y: p.y), modifiers: mods); w.endDrag()
        }
        #expect(w.selectedNodeIDs == [a, b])
        #expect(w.selectedPage?.nodes.map(\.frame) == frames, "a click moves nothing")
    }
}
