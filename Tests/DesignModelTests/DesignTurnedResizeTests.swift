// DesignTurnedResizeTests.swift (transform DT-u, #4223): a side or corner handle of a turned or mirrored
// layer resizes it in its own axes. The pointer's sweep is taken into the node's unturned, unmirrored
// frame, the handle's edge follows it there, the opposite edge stays put on the page, and the centre
// moves along the turn; the drag is one Resize step. An upright layer resizes as it always has. The
// expected points are worked out here by hand. Plan: Tests/mutations/DesignModel.DesignCanvasEditing.json.
// Runs on Linux and macOS.
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

@Suite struct DesignTurnedResizeTests {
    /// Desktop (node-1) holding a 100 × 50 rectangle (node-2) at 100, 100, selected, turned `degrees`.
    static func turned(_ degrees: Double, flipX: Bool = false) throws -> DesignWorkspace {
        var workspace = openDesign()
        try workspace.addNode(.rectangle, frame: rc(100, 100, 100, 50), in: "node-1")
        workspace.selectItem("node-2")
        if flipX { workspace.runTransform(.flip(.horizontal)) }
        if degrees != 0 { workspace.runTransform(.rotate(by: degrees, drag: nil)) }
        return workspace
    }

    /// The page point of `local` (a point of the node's unturned frame) for a node centred at `centre`,
    /// turned clockwise `degrees` and mirrored across its vertical centre line when `flipX`.
    static func shown(_ local: DesignPoint, centre: DesignPoint, _ degrees: Double, flipX: Bool = false) -> DesignPoint {
        let (a, x, y) = (degrees * .pi / 180, (local.x - centre.x) * (flipX ? -1 : 1), local.y - centre.y)
        return pt(centre.x + x * cos(a) - y * sin(a), centre.y + x * sin(a) + y * cos(a))
    }

    static func near(_ a: DesignPoint, _ b: DesignPoint) -> Bool {
        abs(a.x - b.x) < 0.01 && abs(a.y - b.y) < 0.01
    }

    @Test func aTurnedRightHandleGrowsAlongTheTurn() throws {
        var workspace = try Self.turned(30)
        let centre = pt(150, 125)
        let handle = Self.shown(pt(200, 125), centre: centre, 30)
        let leftMiddle = Self.shown(pt(100, 125), centre: centre, 30)
        #expect(workspace.handle(at: handle) == .right)
        let a = 30 * Double.pi / 180
        workspace.drag(from: handle, to: handle)
        workspace.drag(from: handle, to: pt(handle.x + 10 * cos(a), handle.y + 10 * sin(a)))
        workspace.drag(from: handle, to: pt(handle.x + 20 * cos(a), handle.y + 20 * sin(a)))
        workspace.endDrag()
        let node = try #require(workspace.treeNode("node-2"))
        #expect(abs(node.frame.width - 120) < 1e-9)
        #expect(abs(node.frame.height - 50) < 1e-9)
        #expect(node.rotation == 30)
        let kept = Self.shown(pt(node.frame.x, node.frame.y + 25), centre: pt(node.frame.x + 60, node.frame.y + 25), 30)
        #expect(Self.near(kept, leftMiddle))
        #expect(workspace.undoActionName == "Undo Resize")
        workspace.undo()
        #expect(workspace.treeNode("node-2")?.frame == rc(100, 100, 100, 50))
        #expect(workspace.treeNode("node-2")?.rotation == 30)
    }

    @Test func aTurnedCornerPinsTheOppositeCorner() throws {
        var workspace = try Self.turned(-45)
        let centre = pt(150, 125)
        let handle = Self.shown(pt(200, 150), centre: centre, -45)
        let topLeft = Self.shown(pt(100, 100), centre: centre, -45)
        #expect(workspace.handle(at: handle) == .bottomRight)
        // 10 along the turned x axis and 6 along the turned y axis.
        let end = Self.shown(pt(210, 156), centre: centre, -45)
        workspace.drag(from: handle, to: end)
        workspace.endDrag()
        let node = try #require(workspace.treeNode("node-2"))
        #expect(abs(node.frame.width - 110) < 1e-9 && abs(node.frame.height - 56) < 1e-9)
        let middle = pt(node.frame.x + 55, node.frame.y + 28)
        #expect(Self.near(Self.shown(pt(node.frame.x, node.frame.y), centre: middle, -45), topLeft))
    }

    @Test func aMirroredNodesHandlesActInItsMirroredAxes() throws {
        var workspace = try Self.turned(0, flipX: true)
        // Mirrored, the node's own right edge shows on the page's left.
        let handle = pt(100, 125)
        #expect(workspace.handle(at: handle) == .right)
        workspace.drag(from: handle, to: pt(80, 125))
        workspace.endDrag()
        let node = try #require(workspace.treeNode("node-2"))
        #expect(abs(node.frame.width - 120) < 1e-9 && abs(node.frame.height - 50) < 1e-9)
        // The page's right edge, the node's own left, stays at 200.
        #expect(abs(node.frame.maxX - 200) < 0.01 && abs(node.frame.x - 80) < 0.01)
        #expect(node.flipX)
    }

    @Test func anUprightResizeIsAsBefore() throws {
        var workspace = try Self.turned(0)
        workspace.drag(from: pt(200, 125), to: pt(220.4, 131))
        workspace.endDrag()
        #expect(workspace.treeNode("node-2")?.frame == rc(100, 100, 100, 50).resized(.right, by: pt(20.4, 6), keepAspect: false, fromCenter: false).wholePoints)
        #expect(workspace.undoActionName == "Undo Resize")
    }
}
