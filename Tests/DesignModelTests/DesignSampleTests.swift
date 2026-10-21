// DesignSampleTests.swift (eyedropper DY-1 written, DY-5 turned on): the workspace as SuiteKernel's SampleTarget
// (DesignSample+Kernel). On a new file (node-1, the white Desktop frame) a grey rectangle node-2 (100 100 200 200)
// sits under a red ellipse node-3 (200 200 200 200). The sample reads the topmost visible painted layer, never the
// selection; a hidden layer is skipped; empty canvas reads nil; an apply is one step and a locked selection
// refuses. The DY-5 cases wait on the adapter's bodies; the tool's existence is checked now. Linux and macOS.
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

    @Test(.disabled("waits on DY-5")) func samplesTopmost() throws {
        let w = try Self.shapes()
        #expect(Self.hex(w.sampledColor(at: Point(x: 250, y: 250), size: .point)) == "#FF0000", "the ellipse on top, not the selection")
        #expect(Self.hex(w.sampledColor(at: Point(x: 120, y: 120), size: .point)) == "#D9D9D9")
        #expect(Self.hex(w.sampledColor(at: Point(x: 1000, y: 900), size: .point)) == "#FFFFFF")
    }

    @Test(.disabled("waits on DY-5")) func skipsHidden() throws {
        var w = try Self.shapes()
        try w.toggleNodeFlag("node-3", .hidden)
        #expect(Self.hex(w.sampledColor(at: Point(x: 250, y: 250), size: .point)) == "#D9D9D9")
    }

    @Test(.disabled("waits on DY-5")) func emptyCanvasIsNil() throws {
        let w = try Self.shapes()
        #expect(w.sampledColor(at: Point(x: 2000, y: 2000), size: .point) == nil)
        #expect(DesignWorkspace().sampledColor(at: Point(x: 10, y: 10), size: .point) == nil)
    }

    @Test(.disabled("waits on DY-5")) func applyIsOneStep() throws {
        var w = try Self.shapes()
        try w.applySample(at: Point(x: 350, y: 350), toStroke: false)
        #expect(w.treeNode("node-2")?.fill == DesignColor(255, 0, 0))
        w.undo()
        #expect(w.treeNode("node-2")?.fill == DesignColor.shape, "one undo puts the whole pick back")
        try w.applySample(at: Point(x: 350, y: 350), toStroke: true)
        #expect(w.treeNode("node-2")?.stroke?.color == DesignColor(255, 0, 0))
        #expect(w.treeNode("node-2")?.fill == DesignColor.shape, "Option-click leaves the fill")
    }

    @Test(.disabled("waits on DY-5")) func lockedSelectionRefuses() throws {
        var w = try Self.shapes()
        try w.toggleNodeFlag("node-2", .locked)
        let before = w
        #expect(throws: (any Error).self) { try w.applySample(at: Point(x: 350, y: 350), toStroke: false) }
        #expect(w == before, "a refused pick changes nothing")
    }
}
