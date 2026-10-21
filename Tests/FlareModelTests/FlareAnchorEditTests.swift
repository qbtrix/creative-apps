// FlareAnchorEditTests.swift (pen-paths FP-1, FP-7): Direct Select's PathEditTarget. The reads (`pathInEdit`, its help,
// the anchor selection clearing on a new item selection) and the edits: an anchor or handle drag as one "Edit Path",
// the anchor marquee, a locked layer, and a scaled layer's space. Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareAnchorEditTests {
    /// A 40 by 30 rectangle at (10, 10), picked with Direct Select.
    static func picked() -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument()
        workspace.selectTool(.rectangle)
        workspace.drag(from: Point(x: 10, y: 10), to: Point(x: 50, y: 40))
        workspace.selectTool(.directSelect)
        workspace.drag(from: Point(x: 30, y: 25), to: Point(x: 30, y: 25))
        return workspace
    }

    /// The anchors of the path in edit.
    static func anchors(_ workspace: FlareWorkspace) -> [PathAnchor] { workspace.pathInEdit?.path.contours.first?.anchors ?? [] }

    /// Where `point` of the path in edit sits in the scene.
    static func scene(_ workspace: FlareWorkspace, _ point: Point) -> Point {
        workspace.pathInEdit.map { $0.toDocument.apply(point) } ?? point
    }

    static func near(_ a: Point?, _ b: Point?) -> Bool {
        guard let a, let b else { return false }
        return abs(a.x - b.x) <= 1e-9 && abs(a.y - b.y) <= 1e-9
    }

    @Test func pathInEditIsTheOneDirectSelectedShape() throws {
        var workspace = Self.picked()
        let edit = try #require(workspace.pathInEdit)
        // Today's rectangle path draws its closing edge as a line back to the start, a fifth anchor on the first.
        #expect(edit.path.contours.first?.anchors.count == 5 && workspace.pathHelp == nil, "\(edit.path.elements)")
        workspace.selectTool(.select)
        #expect(workspace.pathInEdit == nil)
        #expect(workspace.pathHelp == "Select one shape with Direct Select to edit its points.")
    }

    @Test func anchorSelectionClearsWhenTheItemSelectionChanges() {
        var workspace = Self.picked()
        workspace.anchorSelection = Selection([AnchorRef(contour: 0, index: 1)])
        workspace.drag(from: Point(x: 30, y: 25), to: Point(x: 30, y: 25))
        #expect(workspace.anchorSelection.ordered == [AnchorRef(contour: 0, index: 1)])
        workspace.drag(from: Point(x: 300, y: 300), to: Point(x: 300, y: 300))
        #expect(workspace.anchorSelection.ordered.isEmpty && workspace.selection.isEmpty && workspace.pathInEdit == nil)
    }

    @Test func onlyPickedAnchorsMove() throws {
        var workspace = Self.picked()
        let before = Self.anchors(workspace)
        workspace.runPath(.select(anchors: [AnchorRef(contour: 0, index: 1)], rect: nil, extend: false))
        workspace.runPath(.move(dx: 30, dy: 0, drag: nil))
        let after = Self.anchors(workspace)
        #expect(after.count == before.count && workspace.undoActionName == "Undo Edit Path")
        for (index, (old, new)) in zip(before, after).enumerated() {
            let moved = index == 1 ? Point(x: old.point.x + 30, y: old.point.y) : old.point
            #expect(new.point == moved, "anchor \(index)")
        }
    }

    @Test func anAnchorDragWinsOverTheItemAndIsOneEditPathStep() throws {
        var workspace = Self.picked()
        let before = Self.anchors(workspace), selection = workspace.selection
        let corner = Self.scene(workspace, try #require(before.dropFirst().first).point)
        workspace.dragChanged(from: corner, to: Point(x: corner.x + 30, y: corner.y))
        let preview = workspace.dragPreview?.items.first { $0.address == selection.first }?.path.contours.first?.anchors
        #expect(preview?.dropFirst().first?.point.x == before.dropFirst().first.map { $0.point.x + 30 })
        workspace.endDrag()
        let after = Self.anchors(workspace)
        #expect(after.map(\.point) == before.enumerated().map { i, a in i == 1 ? Point(x: a.point.x + 30, y: a.point.y) : a.point })
        #expect(workspace.selection == selection && workspace.anchorSelection.ordered == [AnchorRef(contour: 0, index: 1)])
        #expect(workspace.undoActionName == "Undo Edit Path" && workspace.dragPreview == nil)
        workspace.undo()
        #expect(Self.anchors(workspace) == before && workspace.selection == selection)
    }

    /// The picked shape's path made one open curve whose middle anchor (30, 10) is smooth: handles (20, 10) and (45, 10).
    static func curved() throws -> FlareWorkspace {
        var workspace = Self.picked()
        let curve = VectorPath(elements: [.move(to: Point(x: 10, y: 30)),
                                          .cubic(control1: Point(x: 10, y: 20), control2: Point(x: 20, y: 10), to: Point(x: 30, y: 10)),
                                          .cubic(control1: Point(x: 45, y: 10), control2: Point(x: 50, y: 20), to: Point(x: 50, y: 30))])
        try workspace.setPath(curve, name: "Edit Path", drag: nil)
        workspace.runPath(.select(anchors: [AnchorRef(contour: 0, index: 1)], rect: nil, extend: false))
        return workspace
    }

    @Test(arguments: [false, true]) func aHandleDragTurnsASmoothPartnerUnlessOptionBreaksIt(breaking: Bool) throws {
        var workspace = try Self.curved()
        let handle = Self.scene(workspace, Point(x: 39, y: 22))  // 15 from the anchor, along (0.6, 0.8)
        workspace.drag(from: Self.scene(workspace, Point(x: 45, y: 10)), to: handle, modifiers: breaking ? [.option] : [])
        let anchor = try #require(Self.anchors(workspace).dropFirst().first)
        #expect(Self.near(anchor.handleOut, Point(x: 39, y: 22)) && workspace.undoActionName == "Undo Edit Path")
        // Smooth: the partner keeps its length, 10, and turns opposite. Broken: it stays and the anchor is a corner.
        #expect(Self.near(anchor.handleIn, breaking ? Point(x: 20, y: 10) : Point(x: 24, y: 2)), "\(anchor)")
        #expect((anchor.kind == .corner) == breaking)
    }

    @Test func theMarqueePicksAnchorsOnlyOfThePickedItem() {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument()
        workspace.selectTool(.rectangle)
        workspace.drag(from: Point(x: 10, y: 10), to: Point(x: 50, y: 40))
        workspace.drag(from: Point(x: 60, y: 10), to: Point(x: 100, y: 40))
        workspace.selectTool(.directSelect)
        workspace.drag(from: Point(x: 30, y: 25), to: Point(x: 30, y: 25))
        let selection = workspace.selection
        workspace.dragChanged(from: Point(x: 2, y: 2), to: Point(x: 110, y: 50))
        #expect(workspace.marquee != nil)
        workspace.endDrag()
        #expect(workspace.selection == selection && workspace.anchorSelection.ordered.count == 5)
        #expect(workspace.anchorSelection.ordered.allSatisfy { $0.contour == 0 })
    }

    @Test func aLockedLayerRefusesWithItsHelp() throws {
        var workspace = Self.picked()
        let before = Self.anchors(workspace), layer = try #require(workspace.selection.first?.layerID)
        workspace.toggleLayerFlag(layer, .locked)
        let help = try #require(workspace.pathHelp)
        #expect(help.hasPrefix("Unlock "))
        workspace.runPath(.select(anchors: [AnchorRef(contour: 0, index: 1)], rect: nil, extend: false))
        workspace.runPath(.move(dx: 30, dy: 0, drag: nil))
        #expect(Self.anchors(workspace) == before && workspace.layerError == .refused(help))
    }

    @Test func aDragOnALayerScaledTwiceMapsThroughItsScale() throws {
        var workspace = Self.picked()
        var document = try #require(workspace.document)
        let layer = try #require(workspace.selection.first?.layerID)
        for (s, scene) in document.scenes.enumerated() {
            for (l, item) in scene.layers.enumerated() where item.id == layer {
                for key in ["scaleX", "scaleY"] { document.scenes[s].layers[l].tracks[key] = [Keyframe(frame: 0, value: 2)] }
            }
        }
        workspace.load(document)
        workspace.selectTool(.directSelect)
        let middle = try #require(workspace.stageList?.items.first.map { $0.transform.apply(Point(x: 30, y: 25)) })
        workspace.drag(from: middle, to: middle)
        let before = Self.anchors(workspace)
        try #require(before.count == 5)
        workspace.runPath(.select(anchors: [AnchorRef(contour: 0, index: 1)], rect: nil, extend: false))
        workspace.runPath(.move(dx: 30, dy: 0, drag: nil))
        #expect(Self.anchors(workspace).dropFirst().first?.point.x == before.dropFirst().first.map { $0.point.x + 15 })
    }
}
