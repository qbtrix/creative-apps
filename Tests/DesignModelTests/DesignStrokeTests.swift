// DesignStrokeTests.swift: stroke-style DK-1 (MJ-DK, the Model walk). The readout half runs now: a node's
// stroke read as the kernel's VectorStroke (its colour and width), nil with no stroke, the selection's stroke,
// and the trim help. The command half is written against the DK-6 bodies and stays disabled until DK-6 turns
// it on: Width 2, Round cap and Dashed are three steps that three undos take back to a plain 1 pt stroke, a
// locked node is skipped with its help, width clamps, and trim never runs in Design. Linux.
@testable import DesignModel
import SuiteKernel
import Testing

/// A new file with one rectangle, selected, carrying `stroke`.
private func rectangle(_ stroke: DesignStroke? = .default) throws -> DesignWorkspace {
    var w = DesignWorkspace()
    w.newFile()
    try w.addNode(.rectangle, frame: DesignRect(x: 40, y: 40, width: 120, height: 80), in: "node-1")
    if let stroke { try w.setStyle(.stroke(stroke)) }
    return w
}

@Suite struct DesignStrokeTests {
    @Test func vectorStrokeCarriesTodaysColourAndWidth() {
        let node = DesignNode(id: "a", name: "A", kind: .rectangle, frame: DesignRect(x: 0, y: 0, width: 10, height: 10),
                              stroke: DesignStroke(color: DesignColor(255, 0, 51), width: 4))
        let stroke = node.vectorStroke
        #expect(stroke?.width == 4)
        #expect(stroke?.color == FillColor(r: 1, g: 0, b: 0.2, a: 1))
        #expect(stroke?.join == .miter && stroke?.cap == .butt)
    }

    @Test func aKernelColourComesBackAsTheSameChannels() {
        let color = DesignColor(255, 0, 51)
        #expect(DesignColor(FillColor(r: 1, g: 0, b: 0.2, a: 1)) == color)
        #expect(DesignColor(FillColor(r: 2, g: -1, b: .nan, a: 1)) == DesignColor(255, 0, 0))
        #expect(DesignColor(FillColor(r: 0.5, g: 0.5, b: 0.5, a: 1)) == DesignColor(128, 128, 128))
    }

    @Test func noStrokeReadsNil() {
        let node = DesignNode(id: "a", name: "A", kind: .rectangle, frame: DesignRect(x: 0, y: 0, width: 10, height: 10))
        #expect(node.vectorStroke == nil)
    }

    @Test func theSelectionsStrokeIsThePrimaryNodes() throws {
        let w = try rectangle(DesignStroke(color: .black, width: 3))
        #expect(w.selectedStroke == w.selectedNode?.vectorStroke)
        #expect(w.selectedStroke?.width == 3)
        #expect(try rectangle(nil).selectedStroke == nil)
    }

    @Test func trimIsForAnimation() throws {
        #expect(try rectangle().trimHelp == "Trim paths are for animation, in Flare and Halo.")
    }

    @Test func thePickersSayWhyTheyAreOff() throws {
        let stroked = try rectangle()
        #expect(stroked.strokeHelp == nil)
        #expect(stroked.strokeStyleHelp == "Stroke styles isn't built yet.")
        #expect(stroked.strokeDashHelp == StrokeRules.waitingCore)
        let plain = try rectangle(nil)
        #expect(plain.strokeStyleHelp == "Add a stroke first." && plain.strokeDashHelp == "Add a stroke first.")
    }

    @Test func thePickersAreListedControls() {
        let all = Set(DesignControlID.all)
        #expect(all.contains("design.inspector.stroke-join") && all.contains("design.inspector.stroke-cap"))
        #expect(all.contains(DesignControlID.inspectorStrokeDash))
    }

    @Test func setStrokeRefusesUntilTheBodiesAreBuilt() throws {
        var w = try rectangle()
        let before = w.selectedNode
        #expect(throws: (any Error).self) { try w.setStroke(VectorStroke(width: 2), name: "Stroke Width", drag: nil) }
        #expect(w.selectedNode == before)
    }
}

@Suite(.disabled("waits on DK-6"))
struct DesignStrokeCommandTests {
    /// MJ-DK step 2 and 3: Width 2, Round cap and Dashed are one step each; three undos give a plain 1 pt stroke.
    @Test func oneStepPerGesture() throws {
        var w = try rectangle()
        let plain = w.selectedStroke
        try w.setStroke(VectorStroke(width: 2), name: "Stroke Width", drag: "width")
        try w.setStroke(VectorStroke(width: 2.5), name: "Stroke Width", drag: "width")
        try w.setStroke(VectorStroke(width: 2, cap: .round), name: "Stroke Cap", drag: nil)
        try w.setStroke(VectorStroke(width: 2, cap: .round), name: "Stroke Dash", drag: nil)
        w.undo(); w.undo(); w.undo()
        #expect(w.selectedStroke == plain)
    }

    @Test func aLockedNodeIsSkippedWithItsHelp() throws {
        var w = try rectangle()
        let id = try #require(w.selectedNodeID)
        try w.setNodeLocked(id, true)
        #expect(w.strokeHelp != nil)
        #expect(throws: (any Error).self) { try w.setStroke(VectorStroke(width: 6), name: "Stroke Width", drag: nil) }
    }

    @Test func widthClamps() throws {
        var w = try rectangle()
        try w.setStroke(VectorStroke(width: -3), name: "Stroke Width", drag: nil)
        #expect(w.selectedStroke?.width == StrokeRules.clampedWidth(-3))
    }

    @Test func removeTakesTheStrokeOff() throws {
        var w = try rectangle()
        try w.setStroke(nil, name: "Remove Stroke", drag: nil)
        #expect(w.selectedStroke == nil && w.selectedNode?.stroke == nil)
    }
}
