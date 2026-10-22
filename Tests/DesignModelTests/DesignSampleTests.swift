// DesignSampleTests.swift (eyedropper DY-1 written, DY-5 turned on): the workspace as SuiteKernel's SampleTarget
// (DesignSample+Kernel). On a new file (node-1, the white Desktop frame) a grey rectangle node-2 (100 100 200 200)
// sits under a red ellipse node-3 (200 200 200 200). The sample reads the topmost visible painted layer, never the
// selection; a hidden layer is skipped; empty canvas reads nil; an apply is one step and a locked selection
// refuses; a gradient reads its colour at the point; the Eyedropper is enabled and a click picks once. Linux and macOS.
import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignSampleTests {
    /// The two overlapping shapes on a new file, node-2 selected.
    static func shapes() throws -> DesignWorkspace {
        var w = openDesign()
        w.gesture(.rectangle, pt(100, 100), pt(300, 300))
        w.gesture(.ellipse, pt(200, 200), pt(400, 400))
        try w.setFill("node-3", DesignColor(255, 0, 0))
        w.selectItem("node-2")
        w.endEditRun()
        return w
    }

    static func hex(_ color: FillColor?) -> String? { color.map(SampleRules.hex) }

    @Test func theToolEnumHasTheEyedropper() {
        #expect(DesignTool.allCases.contains(.eyedropper))
        #expect(DesignTool(rawValue: "eyedropper") == .eyedropper)
        #expect(DesignTool.eyedropper.nodeKind == nil)
    }

    @Test func theAdapterSaysWhyWithNoDocument() {
        #expect(DesignWorkspace().sampleHelp == "Open a design first.")
        #expect(openDesign().sampleHelp == nil)
    }

    /// #3987: the palette's Eyedropper is enabled, and with nothing selected the pick refuses and changes nothing.
    @Test func theEyedropperIsEnabledAndNeedsASelection() throws {
        #expect(DesignTool.eyedropper.isEnabled)
        var w = try Self.shapes()
        w.deselect()
        let before = w
        #expect(throws: DesignRefusal.nothingSelected) { try w.applySample(at: Point(x: 350, y: 350), toStroke: false) }
        #expect(w == before, "a refused pick changes nothing")
    }

    /// A gradient reads its colour at the point (`GradientRules.color(of:at:)` on the line's projection), not its
    /// first stop: red to blue, left to right across node-2, above the ellipse.
    @Test func gradientAtPoint() throws {
        var w = try Self.shapes()
        let box = try #require(w.fillSelection?.box)
        let red = FillColor(r: 1, g: 0, b: 0), blue = FillColor(r: 0, g: 0, b: 1)
        let redToBlue = Fill.linear(
            stops: [GradientStop(offset: 0, color: red), GradientStop(offset: 1, color: blue)],
            start: Point(x: box.minX, y: box.minY), end: Point(x: box.maxX, y: box.minY))
        try w.setFill(redToBlue, in: box, name: "Fill", drag: nil)
        #expect(Self.hex(w.sampledColor(at: Point(x: 200, y: 150), size: .point)) == "#800080")
        #expect(Self.hex(w.sampledColor(at: Point(x: 120, y: 150), size: .point)) == "#E6001A")
    }

    /// A click with the Eyedropper is one step however far the pointer wanders before release, and it lands on
    /// the selection only: the ellipse it read keeps its red, the rectangle stays selected, the tool stays.
    @Test func aClickPicksOnce() throws {
        var w = try Self.shapes()
        w.selectTool(.eyedropper)
        let steps = w.historyListing.steps.count
        w.drag(from: pt(350, 350), to: pt(360, 360))
        w.drag(from: pt(360, 360), to: pt(370, 370))
        w.endDrag()
        #expect(w.historyListing.steps.count == steps + 1, "one click, one step")
        #expect(w.treeNode("node-2")?.fill == DesignColor(255, 0, 0))
        #expect(w.treeNode("node-3")?.fill == DesignColor(255, 0, 0))
        #expect(w.selectedNodeID == "node-2" && w.tool == .eyedropper)
    }

    /// Journey steps 1 and 4: the Eyedropper keeps the selection, and back to Move keeps it too.
    @Test func pickJourneyWalk() throws {
        var w = try Self.shapes()
        w.selectTool(.eyedropper)
        #expect(w.tool == .eyedropper)
        #expect(w.selectedNodeID == "node-2", "choosing the Eyedropper keeps the selection")
        w.selectTool(.move)
        #expect(w.tool == .move)
        #expect(w.selectedNodeID == "node-2", "back to Move, the rectangle is still selected")
    }

    /// Journey steps 2 and 3 through the tool's click on the canvas, not applySample.
    @Test func pickJourneyWalkClicks() throws {
        var w = try Self.shapes()
        w.selectTool(.eyedropper)
        w.drag(from: pt(350, 350), to: pt(350, 350))
        w.endDrag()
        #expect(w.treeNode("node-2")?.fill == DesignColor(255, 0, 0), "a click picks the ellipse's red as the fill")
        w.undo()
        #expect(w.treeNode("node-2")?.fill == DesignColor.shape, "the pick is one step")
        w.drag(from: pt(350, 350), to: pt(350, 350), modifiers: .option)
        w.endDrag()
        #expect(w.treeNode("node-2")?.stroke?.color == DesignColor(255, 0, 0), "Option-click sets the stroke")
        #expect(w.treeNode("node-2")?.fill == DesignColor.shape, "Option-click leaves the fill")
        #expect(w.selectedNodeID == "node-2")
    }

    @Test func samplesTopmost() throws {
        let w = try Self.shapes()
        #expect(Self.hex(w.sampledColor(at: Point(x: 250, y: 250), size: .point)) == "#FF0000", "the ellipse on top, not the selection")
        #expect(Self.hex(w.sampledColor(at: Point(x: 120, y: 120), size: .point)) == "#D9D9D9")
        #expect(Self.hex(w.sampledColor(at: Point(x: 1000, y: 900), size: .point)) == "#FFFFFF")
    }

    @Test func skipsHidden() throws {
        var w = try Self.shapes()
        try w.toggleNodeFlag("node-3", .hidden)
        #expect(Self.hex(w.sampledColor(at: Point(x: 250, y: 250), size: .point)) == "#D9D9D9")
    }

    @Test func emptyCanvasIsNil() throws {
        let w = try Self.shapes()
        #expect(w.sampledColor(at: Point(x: 2000, y: 2000), size: .point) == nil)
        #expect(DesignWorkspace().sampledColor(at: Point(x: 10, y: 10), size: .point) == nil)
    }

    @Test func applyIsOneStep() throws {
        var w = try Self.shapes()
        try w.applySample(at: Point(x: 350, y: 350), toStroke: false)
        #expect(w.treeNode("node-2")?.fill == DesignColor(255, 0, 0))
        w.undo()
        #expect(w.treeNode("node-2")?.fill == DesignColor.shape, "one undo puts the whole pick back")
        try w.applySample(at: Point(x: 350, y: 350), toStroke: true)
        #expect(w.treeNode("node-2")?.stroke?.color == DesignColor(255, 0, 0))
        #expect(w.treeNode("node-2")?.fill == DesignColor.shape, "Option-click leaves the fill")
    }

    /// #3991: the sample size reaches the pick, not only the loupe. Just outside the red ellipse's right edge a
    /// point reads the white frame, a 5 × 5 square reads some red too, and the pick applies what the loupe showed.
    @Test func sizeChangesThePick() throws {
        var w = try Self.shapes()
        w.selectTool(.eyedropper)
        let edge = pt(401, 300)
        let point = w.loupe(at: edge, modifiers: [])?.color
        w.setSampleSize(.fiveByFive)
        let square = w.loupe(at: edge, modifiers: [])?.color
        #expect(square != nil)
        #expect(square != point, "a 5 × 5 square across the edge reads another colour than the point")
        try w.pick(at: edge, toStroke: false)
        #expect(w.treeNode("node-2")?.fill == square, "the pick applies the square the loupe showed")
    }

    @Test func lockedSelectionRefuses() throws {
        var w = try Self.shapes()
        try w.toggleNodeFlag("node-2", .locked)
        let before = w
        #expect(throws: (any Error).self) { try w.applySample(at: Point(x: 350, y: 350), toStroke: false) }
        #expect(w == before, "a refused pick changes nothing")
    }
}
