// DesignTransformTests.swift (transform DT-1 written, DT-5 turned on): MJ-DT, the Model walk of a node's
// turn and mirrors. A node keeps `rotation` (clockwise degrees about its frame's centre) and `flipX` /
// `flipY` beside its unturned `frame`, so an old file without the keys opens upright and a file with
// upright nodes is written as before. The transform commands' walk runs on DesignTransform+Kernel's
// bodies (DT-5): a turn keeps the centre, several turn about the union in one step, and the hit test
// follows the turned outline. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import SuiteKernel
import Testing

/// A node as a file written before transforms has it: no `rotation`, `flipX` or `flipY` key.
private let oldNode = #"""
    {"children":[],"fill":{"blue":217,"green":217,"red":217},"frame":{"height":100,"width":200,"x":10,"y":20},
    "id":"node-2","isHidden":false,"isLocked":false,"kind":"rectangle","name":"A","text":""}
    """#

/// Desktop (node-1) holding a 200 × 100 rectangle (node-2) at 100, 100, selected.
private func sample() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(100, 100, 200, 100), in: "node-1")
    workspace.selectItem("node-2")
    return workspace
}

@Suite struct DesignTransformTests {
    @Test func anOldNodeOpensUpright() throws {
        let node = try JSONDecoder().decode(DesignNode.self, from: Data(oldNode.utf8))
        #expect(node.rotation == 0)
        #expect(!node.flipX && !node.flipY)
        #expect(node.transformBox == TransformBox(box: Rect(minX: 10, minY: 20, maxX: 210, maxY: 120)))
    }

    @Test func aTurnAndMirrorsSaveOpenAndCopy() throws {
        var node = DesignNode(id: "node-2", name: "A", kind: .rectangle, frame: rc(0, 0, 200, 100))
        (node.rotation, node.flipX, node.flipY) = (15, true, true)
        let opened = try JSONDecoder().decode(DesignNode.self, from: JSONEncoder().encode(node))
        #expect(opened.rotation == 15)
        #expect(opened.flipX && opened.flipY)
        let copy = DesignNode(id: "node-9", copying: node)
        #expect(copy.rotation == 15)
        #expect(copy.flipX && copy.flipY)
        #expect(copy.transformBox.degrees == 15)
    }

    @Test func anUprightNodeWritesNoTransformKeys() throws {
        let plain = DesignNode(id: "node-3", name: "B", kind: .rectangle, frame: rc(0, 0, 10, 10))
        let json = String(decoding: try JSONEncoder().encode(plain), as: UTF8.self)
        #expect(!json.contains("rotation"))
        #expect(!json.contains("flip"))
        // The keys the node did write are the ones a file from before transforms has.
        #expect(json.contains("\"cornerRadius\"") && json.contains("\"opacity\"") && json.contains("\"textStyle\""))
    }

    /// DT-1's stub: the hit test asks the node, which answers by its unturned frame.
    @Test func theHitTestAsksTheNode() throws {
        let workspace = try sample()
        let node = try #require(workspace.treeNode("node-2"))
        #expect(node.contains(DesignPoint(x: 150, y: 150)))
        #expect(!node.contains(DesignPoint(x: 350, y: 150)))
        #expect(workspace.hitTest(DesignPoint(x: 150, y: 150)) == "node-2")
    }

    @Test func helpSaysWhyItCantTransform() throws {
        var workspace = try sample()
        #expect(workspace.transformSelection == workspace.treeNode("node-2")?.transformBox)
        #expect(workspace.turnHelp == nil)
        try workspace.setNodeLocked("node-2", true)
        #expect(workspace.turnHelp == workspace.lockHelp("node-2"))
        workspace.deselect()
        #expect(workspace.transformSelection == nil)
        #expect(workspace.turnHelp == "Select a layer first.")
    }

    /// Object > Flip and Rotate 90° are on over a layer (the catalog has the specs, DT-6) and off with
    /// the rows' reason with nothing selected.
    @Test func objectItemsSayWhyTheyAreOff() throws {
        var workspace = try sample()
        for id in ["transform.flip", "transform.rotate"] {
            #expect(DesignMenuState.spec(id).availability(DesignMenuState(workspace: workspace, hasWindow: true)) == .available)
        }
        workspace.deselect()
        let state = DesignMenuState(workspace: workspace, hasWindow: true)
        for id in ["transform.flip", "transform.rotate"] {
            #expect(DesignMenuState.spec(id).availability(state) == .unavailable("Select a layer first."))
        }
        #expect(DesignMenuState.spec("object.nothing").availability(state) == .unavailable("Design has no object.nothing command."))
        #expect(DesignControlID.all.contains(DesignControlID.inspectorFlip("horizontal")))
    }

    @Test
    func turnKeepsCentre() throws {
        var workspace = try sample()
        workspace.runTransform(.rotate(by: 90, drag: nil))
        let node = try #require(workspace.treeNode("node-2"))
        #expect(node.rotation == 90)
        #expect(node.frame == rc(100, 100, 200, 100))
        let bounds = TransformRules.bounds(of: node.transformBox)
        #expect(abs((bounds.minX + bounds.maxX) / 2 - 200) < 1e-9)
        #expect(abs((bounds.minY + bounds.maxY) / 2 - 150) < 1e-9)
    }

    @Test
    func flipKeepsFrame() throws {
        var workspace = try sample()
        workspace.runTransform(.flip(.horizontal))
        let node = try #require(workspace.treeNode("node-2"))
        #expect(node.flipX && !node.flipY)
        #expect(node.frame == rc(100, 100, 200, 100))
    }

    @Test
    func severalTurnAboutUnionInOneStep() throws {
        var workspace = try sample()
        try workspace.addNode(.rectangle, frame: rc(400, 100, 100, 100), in: "node-1")
        workspace.selectItem("node-2")
        workspace.toggleSelection("node-3")
        workspace.runTransform(.rotate(by: 180, drag: nil))
        #expect(workspace.treeNode("node-2")?.frame == rc(300, 100, 200, 100))
        #expect(workspace.treeNode("node-3")?.frame == rc(100, 100, 100, 100))
        workspace.undo()
        #expect(workspace.treeNode("node-2")?.rotation == 0 && workspace.treeNode("node-3")?.rotation == 0)
    }

    @Test
    func lockedRefuses() throws {
        var workspace = try sample()
        try workspace.setNodeLocked("node-2", true)
        workspace.runTransform(.rotate(by: 30, drag: nil))
        #expect(workspace.treeNode("node-2")?.rotation == 0)
    }

    @Test
    func cornerGapMisses() throws {
        var workspace = try sample()
        workspace.runTransform(.rotate(by: 45, drag: nil))
        // The unturned frame's top-left corner lies outside the turned outline.
        #expect(workspace.hitTest(DesignPoint(x: 102, y: 102)) != "node-2")
        #expect(workspace.hitTest(DesignPoint(x: 200, y: 150)) == "node-2")
    }

    @Test
    func oneStepPerGesture() throws {
        var workspace = try sample()
        for _ in 0..<60 { workspace.runTransform(.rotate(by: 0.25, drag: "knob")) }
        #expect(abs((workspace.treeNode("node-2")?.rotation ?? 0) - 15) < 1e-9)
        workspace.runTransform(.flip(.vertical))
        workspace.undo()
        workspace.undo()
        #expect(workspace.treeNode("node-2")?.rotation == 0)
    }
}
