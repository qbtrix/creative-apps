// DesignSnapMoveTests.swift: snapping SN-4 on `cards`. Moves of one layer, several and an
// Option-drag copy snap to lines and gaps before whole points; `.noSnap` snaps nothing. Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignSnapMoveTests {
    /// cards' ids: Desktop holds A, B, C, Title, Pair (E1, E2), Locked and Hidden.
    static let (desktop, a, b, c) = ("node-1", "node-2", "node-3", "node-4")

    /// `cards` with `ids` selected.
    func cards(_ ids: String...) -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        for (index, id) in ids.enumerated() {
            if index == 0 { workspace.selectItem(id) } else { workspace.toggleSelection(id) }
        }
        return workspace
    }

    @Test func aMoveSnapsToALineBeforeWholePoints() {
        var workspace = cards(Self.a)
        // A by (197.4, 0.4): its left edge reaches B's at x 300 and its top C's at y 100.
        workspace.drag(from: pt(150, 140), to: pt(347.4, 140.4), modifiers: [])
        #expect(workspace.frame(Self.a) == rc(300, 100, 100, 80))
        #expect((workspace.snapGuides?.summary ?? "").contains("x 300"))
        workspace.endDrag()
        #expect(workspace.frame(Self.a) == rc(300, 100, 100, 80) && workspace.undoActionName == "Undo Move")
        #expect(workspace.snapGuides == nil)
        var raw = cards(Self.a)  // `.noSnap`: whole points only.
        raw.drag(from: pt(150, 140), to: pt(347.4, 140.4), modifiers: .noSnap)
        #expect(raw.frame(Self.a) == rc(297, 100, 100, 80) && raw.snapGuides == DesignSnapGuides.empty)
    }

    @Test func aSmallMoveStaysWhereItLinesUpAndNamesItsGaps() {
        var workspace = cards(Self.a)
        workspace.drag(from: pt(150, 140), to: pt(150.4, 140.4), modifiers: [])
        #expect(workspace.frame(Self.a) == rc(100, 100, 100, 80))
        #expect(["gap x 100", "gap y 28"].allSatisfy((workspace.snapGuides?.summary ?? "").contains))
    }

    @Test func aSnapComesBeforeTheRoundingAndStillEndsOnWholePoints() throws {
        var workspace = cards(Self.a)
        // A by (196.6, 0): rounding first would land x 297 and miss B's edge; the snap lands 300.
        workspace.drag(from: pt(150, 140), to: pt(346.6, 140), modifiers: [])
        #expect(workspace.frame(Self.a) == rc(300, 100, 100, 80))
        var fractional = cards()
        try fractional.addNode(.rectangle, frame: rc(1300.5, 800, 50, 50), in: Self.desktop)
        fractional.selectItem(Self.a)
        // A by (1197.4, 0): its left edge snaps to 1300.5, then lands on the whole point 1301.
        fractional.drag(from: pt(150, 140), to: pt(1347.4, 140), modifiers: [])
        #expect(fractional.frame(Self.a) == rc(1301, 100, 100, 80))
    }

    @Test func severalLayersSnapTheirBoundsAndKeepTheirGap() {
        var workspace = cards(Self.a, Self.b)
        // The box (100, 100, 400, 120) by (0, 277.6): its bottom reaches Pair's bottom at y 500.
        workspace.drag(from: pt(150, 140), to: pt(150, 417.6), modifiers: [])
        #expect(workspace.gesture?.route == .moveSeveral([Self.a, Self.b]))
        #expect(workspace.frame(Self.a) == rc(100, 380, 100, 80) && workspace.frame(Self.b) == rc(300, 420, 200, 80))
        #expect((workspace.snapGuides?.summary ?? "").contains("y 500"))
        workspace.endDrag()
        #expect(workspace.undoActionName == "Undo Move" && workspace.snapGuides == nil)
        var far = cards(Self.a, Self.b)  // By (0, 457.6): B alone would reach y 600; the box doesn't.
        far.drag(from: pt(150, 140), to: pt(150, 597.6), modifiers: [])
        #expect(far.frame(Self.a) == rc(100, 558, 100, 80))
    }

    @Test func anOptionDragCopySnapsAsOneDuplicateStep() throws {
        var workspace = cards(Self.a, Self.b)
        let steps = workspace.history.undo.count
        workspace.drag(from: pt(150, 140), to: pt(150, 417.6), modifiers: .option)
        workspace.endDrag()
        #expect(workspace.frame(Self.a) == rc(100, 100, 100, 80) && workspace.frame(Self.b) == rc(300, 140, 200, 80))
        let children = try #require(workspace.selectedPage?.nodes.first?.children)
        let copies = children.filter { ($0.name == "A" || $0.name == "B") && $0.id != Self.a && $0.id != Self.b }
        #expect(copies.map(\.frame) == [rc(100, 380, 100, 80), rc(300, 420, 200, 80)])
        #expect(workspace.history.undo.count == steps + 1 && workspace.undoActionName == "Undo Duplicate")
    }

    @Test func aMoveSnapsToAnEqualGap() {
        var workspace = cards(Self.c)
        // C by (-97, 0.4): x 603 is 3 off the gap B leaves to A (100).
        workspace.drag(from: pt(750, 160), to: pt(653, 160.4), modifiers: [])
        #expect(workspace.frame(Self.c) == rc(600, 100, 100, 120))
        #expect((workspace.snapGuides?.summary ?? "").contains("spacing x 100"))
    }

    @Test func aLongDragBuildsTheEngineOnceAndEndsAsItsLastSample() {
        var workspace = cards(Self.a)
        var last = pt(150, 140)
        for step in 1...120 {
            last = pt(150 + Double(step) * 1.7, 140 + Double(step % 7) * 0.9)
            workspace.drag(from: pt(150, 140), to: last, modifiers: [])
        }
        #expect(workspace.gesture?.snapBuilds == 1)
        var once = cards(Self.a)
        once.drag(from: pt(150, 140), to: last, modifiers: [])
        #expect(workspace.pages == once.pages && workspace.snapGuides == once.snapGuides)
        var draw = cards()  // A draw builds its engine once at the press too (SN-5).
        draw.selectTool(.rectangle)
        draw.drag(from: pt(497.5, 137.6), to: pt(697.2, 222.3), modifiers: [])
        #expect(draw.gesture?.snapBuilds == 1 && draw.snapGuides?.lines.isEmpty == false)
    }
}
