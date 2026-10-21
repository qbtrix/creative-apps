// DesignGradientTests.swift (gradient-fill DG-1 written, DG-4 turns on): MJ-DG, the Model walk of a
// node's gradient fill. A node keeps its gradient as the kernel's `Fill` with its points in the node's
// unit box (0...1), so an old file without the key opens with none and a resize never touches it.
// The schema tests run now; the fill commands' walk is disabled by name until DG-4 builds the bodies
// of DesignFill+Kernel. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import SuiteKernel
import Testing

/// A node as a file written before gradients has it: no `gradient` key.
private let oldNode = #"""
    {"children":[],"fill":{"blue":217,"green":217,"red":217},"frame":{"height":100,"width":200,"x":10,"y":20},
    "id":"node-2","isHidden":false,"isLocked":false,"kind":"rectangle","name":"A","text":""}
    """#

/// Blue to white, left to right across the unit box.
private let unitLinear = Fill.linear(
    stops: [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 1)), GradientStop(offset: 1, color: .white)],
    start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))

/// Desktop (node-1) holding a 200 × 100 rectangle (node-2), selected.
private func sample() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(100, 100, 200, 100), in: "node-1")
    workspace.selectItem("node-2")
    return workspace
}

@Suite struct DesignGradientTests {
    @Test func anOldNodeWithoutAGradientDecodes() throws {
        let node = try JSONDecoder().decode(DesignNode.self, from: Data(oldNode.utf8))
        #expect(node.gradient == nil)
        #expect(node.fill == DesignColor(217, 217, 217))
        #expect(node.frame == rc(10, 20, 200, 100))
    }

    @Test func aGradientSavesOpensAndCopies() throws {
        let node = DesignNode(id: "node-2", name: "A", kind: .rectangle, frame: rc(0, 0, 200, 100), gradient: unitLinear)
        let opened = try JSONDecoder().decode(DesignNode.self, from: JSONEncoder().encode(node))
        #expect(opened.gradient == unitLinear)
        #expect(DesignNode(id: "node-9", copying: node).gradient == unitLinear)
        // A node without one writes no key, so files without gradients stay as they were.
        let plain = DesignNode(id: "node-3", name: "B", kind: .rectangle, frame: rc(0, 0, 10, 10))
        #expect(!String(decoding: try JSONEncoder().encode(plain), as: UTF8.self).contains("gradient"))
    }

    @Test(.disabled("DG-4 builds DesignFill+Kernel's bodies"))
    func linearStoresUnitPoints() throws {
        var workspace = try sample()
        workspace.runFill(.type(.linear))
        guard case .linear(_, let start, let end) = workspace.treeNode("node-2")?.gradient else {
            Issue.record("no linear gradient")
            return
        }
        #expect(start == Point(x: 0, y: 0.5))
        #expect(end == Point(x: 1, y: 0.5))
    }

    @Test(.disabled("DG-4 builds DesignFill+Kernel's bodies"))
    func resizeKeepsAngle() throws {
        var workspace = try sample()
        workspace.runFill(.type(.linear))
        workspace.runFill(.angle(90, drag: nil))
        try workspace.setNodeFrame("node-2", x: 100, y: 100, width: 400, height: 50)
        let selection = try #require(workspace.fillSelection)
        guard case .linear(_, let start, let end) = selection.fill else {
            Issue.record("no linear gradient")
            return
        }
        #expect(start.x == end.x)
        #expect(start.y < end.y)
    }

    @Test(.disabled("DG-4 builds DesignFill+Kernel's bodies"))
    func lockedRefuses() throws {
        var workspace = try sample()
        try workspace.setNodeLocked("node-2", true)
        #expect(workspace.fillHelp == workspace.lockHelp("node-2"))
        workspace.runFill(.type(.linear))
        #expect(workspace.treeNode("node-2")?.gradient == nil)
    }

    @Test(.disabled("DG-4 builds DesignFill+Kernel's bodies"))
    func oneStepForSeveral() throws {
        var workspace = try sample()
        try workspace.addNode(.rectangle, frame: rc(400, 100, 50, 50), in: "node-1")
        try workspace.addNode(.ellipse, frame: rc(500, 100, 50, 50), in: "node-1")
        workspace.selectItem("node-2")
        workspace.toggleSelection("node-3")
        workspace.toggleSelection("node-4")
        workspace.runFill(.type(.radial))
        #expect(["node-2", "node-3", "node-4"].allSatisfy { workspace.treeNode($0)?.gradient != nil })
        workspace.undo()
        #expect(["node-2", "node-3", "node-4"].allSatisfy { workspace.treeNode($0)?.gradient == nil })
    }

    @Test(.disabled("DG-4 builds DesignFill+Kernel's bodies"))
    func oneStepPerGesture() throws {
        var workspace = try sample()
        workspace.runFill(.type(.linear))
        for degrees in stride(from: 0.0, through: 90, by: 10) { workspace.runFill(.angle(degrees, drag: "scrub")) }
        #expect(workspace.undoActionName == "Undo Gradient Angle")
        workspace.undo()
        #expect(workspace.undoActionName == "Undo Fill Type")
    }
}
