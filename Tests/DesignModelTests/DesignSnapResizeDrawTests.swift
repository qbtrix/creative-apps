// DesignSnapResizeDrawTests.swift: snapping SN-5 on `cards`, `.live`. A resize (one layer or
// several, Shift, Option) snaps only its dragged edges; a draw and a Text drag snap their start
// and end; a click places its default box unsnapped; `.noSnap` snaps nothing. Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignSnapResizeDrawTests {
    /// cards' ids: Desktop holds A, B, C, Title, Pair (E1, E2), Locked and Hidden.
    static let (a, b) = ("node-2", "node-3")
    /// A's bottom-right handle, and 2.4 pt short of B's left edge (x 300) and 0.4 below B's centre (y 180).
    static let (corner, short) = (pt(200, 180), pt(297.6, 180.4))

    /// `cards` on `.live` with `ids` selected and `tool` chosen.
    func cards(_ tool: DesignTool = .move, _ ids: String...) -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        workspace.useServices(.live)
        for (index, id) in ids.enumerated() {
            if index == 0 { workspace.selectItem(id) } else { workspace.toggleSelection(id) }
        }
        workspace.selectTool(tool)
        return workspace
    }

    /// A's frame after its bottom-right handle is dragged to `end` with `modifiers`.
    func resizeA(to end: DesignPoint = short, _ modifiers: DesignModifiers = []) -> DesignRect? {
        var workspace = cards(.move, Self.a)
        workspace.gesture(.move, Self.corner, end, modifiers)
        return workspace.frame(Self.a)
    }

    @Test func aResizeSnapsTheEdgeItsHandleDrags() {
        var workspace = cards(.move, Self.a)
        workspace.drag(from: Self.corner, to: Self.short, modifiers: [])
        #expect(workspace.gesture?.snapBuilds == 1)
        #expect((workspace.snapGuides?.summary ?? "").contains("x 300"))
        workspace.endDrag()
        #expect(workspace.frame(Self.a) == rc(100, 100, 200, 80) && workspace.undoActionName == "Undo Resize")
        #expect(workspace.snapGuides == nil)
        #expect(resizeA(.noSnap) == rc(100, 100, 198, 80))
    }

    @Test func shiftKeepsTheAspectAndOptionTheCentre() {
        #expect(resizeA(.shift) == rc(100, 100, 200, 160))
        #expect(resizeA(.option) == rc(0, 100, 300, 80))
        // Shift to (253, 215): the aspect leads on x (253, no line); its bottom 222.4 meets y 220,
        // which sets the scale, 1.5, and x follows it.
        #expect(resizeA(to: pt(253, 215), .shift) == rc(100, 100, 150, 120))
    }

    @Test func severalLayersSnapTheirBoxsDraggedEdge() {
        var workspace = cards(.move, Self.a, Self.b)
        // The box (100, 100, 400, 120) by (197.6, 0) from its bottom-right: onto C's left edge, 700.
        workspace.drag(from: pt(500, 220), to: pt(697.6, 220), modifiers: [])
        #expect(workspace.gesture?.route == .resizeSeveral([Self.a, Self.b], .bottomRight))
        #expect(workspace.selectionBounds?.maxX == 700 && workspace.selectionBounds?.x == 100)
        workspace.endDrag()
        #expect(workspace.undoActionName == "Undo Resize")
        var raw = cards(.move, Self.a, Self.b)
        raw.gesture(.move, pt(500, 220), pt(697.6, 220), .noSnap)
        #expect(raw.selectionBounds.map { abs($0.maxX - 697.6) < 0.001 } == true)
    }

    @Test func aDrawSnapsItsStartAndEnd() {
        let (from, to) = (pt(497.5, 137.6), pt(697.2, 222.3))
        var workspace = cards(.rectangle)
        workspace.drag(from: from, to: to, modifiers: [])
        #expect(workspace.gesture?.snapBuilds == 1 && workspace.snapGuides?.lines.isEmpty == false)
        workspace.endDrag()
        #expect(workspace.selectedNode?.frame == rc(500, 140, 200, 80) && workspace.undoActionName == "Undo Add Rectangle")
        var raw = cards(.rectangle)
        raw.gesture(.rectangle, from, to, .noSnap)
        #expect(raw.selectedNode?.frame == rc(498, 138, 199, 84))
        // Shift: the end's nearer axis (x 700), then the square from the snapped start.
        var square = cards(.rectangle)
        square.gesture(.rectangle, from, pt(697.2, 230), .shift)
        #expect(square.selectedNode?.frame == rc(500, 140, 200, 200))
    }

    @Test func aTextDragSnapsItsBox() {
        var workspace = cards(.text)
        workspace.gesture(.text, pt(497.5, 137.6), pt(697.2, 160))
        let frame = workspace.selectedNode?.frame
        #expect(frame?.x == 500 && frame?.width == 200 && workspace.selectedNode?.textStyle.fixedWidth == true)
    }

    @Test func aClickPlacesTheDefaultBoxUnsnapped() {
        var workspace = cards(.rectangle)
        workspace.gesture(.rectangle, pt(497.5, 137.6), pt(497.5, 137.6))
        let size = DesignNodeKind.rectangle.defaultSize
        #expect(workspace.selectedNode?.frame == rc(498, 138, size.width, size.height))
    }
}
