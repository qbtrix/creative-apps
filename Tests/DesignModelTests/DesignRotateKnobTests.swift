// DesignRotateKnobTests.swift (transform DT-u, #4188): the selection's rotate knob on the canvas. A press
// finds every handle, the knob included, where the turned node shows it (the kernel's `BoxMath.handles`
// on the unturned frame, turned about its centre), and a drag from the knob turns the node about that
// centre in one undo step, Shift snapping to the kernel's 15°. The expected spots are worked out here by
// hand, never from the adapter. Plan: Tests/mutations/DesignModel.DesignCanvasEditing.json. Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignRotateKnobTests {
    /// Desktop (node-1) holding a 200 × 100 rectangle (node-2) at 100, 100, selected, turned `degrees`.
    static func turned(_ degrees: Double) throws -> DesignWorkspace {
        var workspace = openDesign()
        try workspace.addNode(.rectangle, frame: rc(100, 100, 200, 100), in: "node-1")
        workspace.selectItem("node-2")
        if degrees != 0 { workspace.runTransform(.rotate(by: degrees, drag: nil)) }
        return workspace
    }

    /// `p` turned clockwise `degrees` about the rectangle's centre (200, 150); document y grows down.
    static func turn(_ p: DesignPoint, _ degrees: Double) -> DesignPoint {
        let (a, x, y) = (degrees * .pi / 180, p.x - 200, p.y - 150)
        return pt(200 + x * cos(a) - y * sin(a), 150 + x * sin(a) + y * cos(a))
    }

    @Test func theKnobIsADesignHandle() {
        #expect(DesignHandle(.rotate) == .rotate)
        #expect(DesignHandle.rotate.editorHandle == .rotate)
        #expect(!DesignHandle.rotate.isCorner)
    }

    @Test func aPressFindsTheKnobWhereTheTurnedNodeShowsIt() throws {
        let workspace = try Self.turned(30)
        // Upright, the knob sits two handles (2 × 6) above the top edge's middle.
        let knob = Self.turn(pt(200, 88), 30)
        #expect(workspace.handle(at: knob) == .rotate)
        #expect(workspace.handle(at: pt(knob.x + 4, knob.y - 4)) == .rotate)
        #expect(workspace.handle(at: pt(200, 88)) != .rotate)
        #expect(workspace.hover(at: knob, modifiers: []).pointer == .resize(.rotate))
        #expect(DesignPointerHint.resize(.rotate).name == "rotate")
    }

    @Test func aResizeHandleHitsAtItsTurnedSpot() throws {
        let workspace = try Self.turned(30)
        #expect(workspace.handle(at: Self.turn(pt(300, 200), 30)) == .bottomRight)
        #expect(workspace.handle(at: Self.turn(pt(100, 150), 30)) == .left)
        #expect(workspace.handle(at: pt(300, 200)) == nil)
    }

    @Test func anUprightNodeShowsTheKnobAboveItsTop() throws {
        let workspace = try Self.turned(0)
        #expect(workspace.handle(at: pt(200, 88)) == .rotate)
        #expect(workspace.handle(at: pt(200, 100)) == .top)
        #expect(rc(100, 100, 200, 100).handles(size: 6)[.rotate] == pt(200, 88))
    }

    @Test func aKnobDragTurnsAboutTheCentreInOneStep() throws {
        var workspace = try Self.turned(30)
        let knob = Self.turn(pt(200, 88), 30)
        workspace.drag(from: knob, to: knob)
        workspace.drag(from: knob, to: Self.turn(pt(240, 100), 30))
        workspace.drag(from: knob, to: Self.turn(pt(262, 150), 30))
        workspace.endDrag()
        let node = try #require(workspace.treeNode("node-2"))
        #expect(abs(node.rotation - 120) < 1e-9)
        #expect(node.frame == rc(100, 100, 200, 100))
        #expect(workspace.undoActionName == "Undo Rotate")
        workspace.undo()
        #expect(workspace.treeNode("node-2")?.rotation == 30)
        workspace.undo()
        #expect(workspace.treeNode("node-2")?.rotation == 0)
        #expect(workspace.undoActionName == "Undo Add Rectangle")
    }

    @Test func shiftSnapsTheKnobsTurnToFifteenDegrees() throws {
        var workspace = try Self.turned(0)
        // From straight up to (240, 100): about 38.7° clockwise, 45° with Shift.
        workspace.drag(from: pt(200, 88), to: pt(240, 100), modifiers: .shift)
        #expect(workspace.treeNode("node-2")?.rotation == 45)
        workspace.drag(from: pt(200, 88), to: pt(240, 100))
        let free = try #require(workspace.treeNode("node-2")?.rotation)
        #expect(abs(free - 38.659808) < 1e-5)
        workspace.endDrag()
    }

    @Test func aLockedNodeShowsNoKnob() throws {
        var workspace = try Self.turned(0)
        try workspace.setNodeLocked("node-2", true)
        #expect(workspace.handle(at: pt(200, 88)) == nil)
    }
}
