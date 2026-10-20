// DesignGradientTests.swift: gradient-fill MJ-DG, the Model walk. A layer's
// gradient saves under its own key, a nil one is left out, old files open
// without one and a copy keeps it (DG-1). The fill commands on a rectangle,
// a resize that keeps the angle, a locked layer's refusal and one step for
// several layers or one drag wait on DG-4's conformance bodies. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignGradientTests {
    /// A rectangle written before gradients existed.
    static let oldNode = #"""
        {"children":[],"fill":{"blue":217,"green":217,"red":217},"frame":{"height":100,"width":200,"x":10,"y":20},
        "id":"node-2","isHidden":false,"isLocked":false,"kind":"rectangle","name":"A","text":""}
        """#

    /// Black at the left of the unit box to white at its right.
    static let linear = Fill.linear(
        stops: [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 0)), GradientStop(offset: 1, color: .white)],
        start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))

    /// A new file with a 200 x 100 rectangle on its frame, selected.
    static func workspace() throws -> (DesignWorkspace, String) {
        var model = DesignWorkspace()
        model.newFile()
        model.useServices(.live)
        let id = try model.addNode(.rectangle, frame: DesignRect(x: 40, y: 40, width: 200, height: 100), in: "node-1")
        model.selectItem(id)
        return (model, id)
    }

    @Test func oldFilesOpenWithoutAGradientAndANilOneIsLeftOut() throws {
        let old = try JSONDecoder().decode(DesignNode.self, from: Data(Self.oldNode.utf8))
        #expect(old.gradient == nil)
        let data = try JSONEncoder().encode(old)
        #expect(String(decoding: data, as: UTF8.self).contains("\"gradient\"") == false)
        var painted = old
        painted.gradient = Self.linear
        let saved = try JSONEncoder().encode(painted)
        #expect(String(decoding: saved, as: UTF8.self).contains("\"gradient\""))
        #expect(try JSONDecoder().decode(DesignNode.self, from: saved) == painted)
        #expect(DesignNode(id: "node-9", copying: painted).gradient == Self.linear)
    }

    @Test(.disabled("waits on DG-4")) func linearOnARectangleRunsLeftToRight() throws {
        var (model, id) = try Self.workspace()
        #expect(model.fillHelp == nil)
        model.runFill(.type(.linear))
        let node = try #require(model.selectedNode)
        guard case .linear(_, let start, let end) = node.gradient else {
            Issue.record("\(id) has no linear gradient")
            return
        }
        #expect(start == Point(x: 0, y: 0.5) && end == Point(x: 1, y: 0.5))
        #expect(model.fillSelection?.box == node.frame.kernelRect)
        #expect(model.undoActionName.hasPrefix("Undo"))
    }

    @Test(.disabled("waits on DG-4")) func resizeKeepsAngle() throws {
        var (model, _) = try Self.workspace()
        model.runFill(.type(.linear))
        model.runFill(.angle(90, drag: nil))
        try model.setStyle(.frame(.width, 400))
        let fill = try #require(model.fillSelection?.fill)
        guard case .linear(_, let start, let end) = fill else {
            Issue.record("not linear: \(fill)")
            return
        }
        #expect(abs(start.x - end.x) < 1e-9, "the line stays vertical after the resize")
    }

    @Test(.disabled("waits on DG-4")) func lockedRefuses() throws {
        var (model, id) = try Self.workspace()
        try model.setNodeLocked(id, true)
        #expect(model.fillHelp == model.lockHelp(id))
        let before = model.selectedNode
        model.runFill(.type(.radial))
        #expect(model.selectedNode == before)
        #expect(throws: (any Error).self) {
            try model.setFill(Self.linear, in: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), name: "Fill", drag: nil)
        }
    }

    @Test(.disabled("waits on DG-4")) func oneStepForSeveral() throws {
        var (model, first) = try Self.workspace()
        let second = try model.addNode(.ellipse, frame: DesignRect(x: 300, y: 40, width: 80, height: 80), in: "node-1")
        let third = try model.addNode(.rectangle, frame: DesignRect(x: 40, y: 200, width: 60, height: 60), in: "node-1")
        model.selectItem(first)
        model.toggleSelection(second)
        model.toggleSelection(third)
        model.runFill(.type(.linear))
        #expect(model.selectedNodes.allSatisfy { $0.gradient != nil })
        model.undo()
        #expect(model.selectedNodes.allSatisfy { $0.gradient == nil }, "one undo clears all three")
    }

    @Test(.disabled("waits on DG-4")) func oneStepPerGesture() throws {
        var (model, _) = try Self.workspace()
        model.runFill(.type(.linear))
        let typed = model.selectedNode?.gradient
        for angle in stride(from: 15.0, through: 90, by: 15) { model.runFill(.angle(angle, drag: "drag-1")) }
        #expect(model.selectedNode?.gradient != typed)
        model.undo()
        #expect(model.selectedNode?.gradient == typed, "one undo takes back the whole drag, not the type")
        #expect(typed != nil)
    }
}
