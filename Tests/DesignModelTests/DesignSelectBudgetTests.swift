// DesignSelectBudgetTests.swift: the select-several budget rows QD-S1 to QD-S4
// (docs/blueprints/design.md section 7.1; packet
// docs/blueprints/design/features/select-several.md, S-8), on `crowd` (2,000
// layers on one page). Each row presses once, untimed, then times 200 drag steps
// of the Move or Rectangle tool through DesignBudget and fails when the p95 is
// over the Linux debug gate (10 × the device target): QD-S1, a move step of a
// frame with 50 children (rewind, translate); QD-S2, a rectangle draw step;
// QD-S3, a resize step of one layer and of 20 through the selection's box;
// QD-S4, a marquee step in Frame 40, whose lookup walks the frames before it.
// Each is ≤ 1 ms / ≤ 10 ms, median and p95. Two bulk rows (#5838) run edit.select
// with 1,500 ids (≤ 25 ms / ≤ 250 ms) and edit.duplicate of those 1,500 layers
// (≤ 50 ms / ≤ 500 ms), each of which once walked the tree per layer and took
// seconds. One row times the inspector's lock and hide reads for one layer, which run
// on every drag step (≤ 0.4 ms / ≤ 4 ms, half the 8 ms step). Each also checks the timed steps did their work, so
// a body that short-circuits can't pass. All the tests are timed, so the suite
// is on the perf list (Tests/perf-suites.txt): the merge gate skips it and
// perf-nightly runs it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignSelectBudgetTests {
    /// `crowd` with a 50th child, node-2001, in Frame 1 (node-1, 10 10 160 150), which holds 49.
    private static func crowdWithFiftyInFrameOne() throws -> DesignWorkspace {
        var pages = DesignFixtures.crowd.pages
        let extra = DesignNode(id: "node-2001", name: "Rectangle 49", kind: .rectangle, frame: rc(150, 136, 8, 8))
        try #require(pages.first?.nodes.first?.id == "node-1")
        pages[0].nodes[0].children.append(extra)
        var workspace = DesignWorkspace()
        workspace.load(pages)
        return workspace
    }

    /// Times 200 drag steps from `start`, alternating between the two `ends`, after one untimed
    /// step to the first end (the press that picks the route). The last timed step goes to `ends[1]`.
    private static func timeSteps(
        _ name: String, on workspace: inout DesignWorkspace, from start: DesignPoint, ends: [DesignPoint],
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> (report: DesignBudget.Report, steps: Int) {
        workspace.drag(from: start, to: ends[0])
        let gate = DesignBudget.linuxDebugGate(device: .milliseconds(1))
        var step = 0
        let report = DesignBudget.expect(name, runs: 200, gate: gate, sourceLocation: sourceLocation) {
            workspace.drag(from: start, to: ends[step % 2])
            step += 1
        }
        #expect(report.median <= gate, "\(name): \(report), median over the gate \(gate)",
                sourceLocation: sourceLocation)
        return (report, step)
    }

    @Test func moveStep() throws {
        var workspace = try Self.crowdWithFiftyInFrameOne()
        let before = try #require(workspace.treeNode("node-1"))
        #expect(before.children.count == 50)
        workspace.selectItem("node-1")
        // (30, 30) is Frame 1's background between its first four rectangles, 20 pt from any handle.
        #expect(workspace.handle(at: pt(30, 30)) == nil)
        #expect(workspace.hitTest(pt(30, 30)) == "node-1")
        let (_, steps) = Self.timeSteps(
            "QD-S1 move step on a frame with 50 children", on: &workspace, from: pt(30, 30),
            ends: [pt(70, 30), pt(33, 37)])
        #expect(steps == 200, "the timed moves ran \(steps) steps, not 200")
        #expect(workspace.gesture?.route == .move("node-1"))
        let moved = try #require(workspace.treeNode("node-1"))
        // The last step, (3, 7), snaps x back onto the frames' left edge at 10 (snapping SN-4).
        #expect(moved.frame == rc(10, 17, 160, 150))
        #expect(moved.children.count == 50)
        for (old, new) in zip(before.children, moved.children) {
            #expect(new.frame.x == old.frame.x && new.frame.y == old.frame.y + 7, "\(new.id) didn't move")
        }
        workspace.endDrag()
        #expect(workspace.undoActionName == "Undo Move")
    }

    @Test func drawStep() {
        var workspace = DesignFixtures.crowd
        workspace.selectTool(.rectangle)
        let (_, steps) = Self.timeSteps(
            "QD-S2 draw step on crowd", on: &workspace, from: pt(30, 30), ends: [pt(130, 110), pt(140, 120)])
        #expect(steps == 200, "the timed draws ran \(steps) steps, not 200")
        #expect(workspace.gesture?.route == .draw(.rectangle))
        #expect(workspace.selectedNode?.kind == .rectangle)
        // The start snaps onto the lines of Frame 1's rectangles at 28 (snapping SN-5).
        #expect(workspace.selectedNode?.frame == rc(28, 28, 112, 92))
        // Each step rewinds before it adds, so Frame 1 holds one new rectangle, not 201.
        #expect(workspace.treeNode("node-1")?.children.count == 50)
        workspace.endDrag()
        #expect(workspace.undoActionName == "Undo Add Rectangle")
    }

    @Test func resizeStep() {
        resizeOneLayer()
        resizeTwentyLayers()
    }

    private func resizeOneLayer() {
        var workspace = DesignFixtures.crowd
        workspace.selectItem("node-1")
        #expect(workspace.handle(at: pt(170, 160)) == .bottomRight)
        let (_, steps) = Self.timeSteps(
            "QD-S3 resize step, one layer, on crowd", on: &workspace, from: pt(170, 160),
            ends: [pt(190, 170), pt(180, 165)])
        #expect(steps == 200, "the timed resizes ran \(steps) steps, not 200")
        #expect(workspace.gesture?.route == .resize("node-1", .bottomRight, rc(10, 10, 160, 150)))
        // The dragged edges snap onto Frame 2's left edge at 185 and the frames' bottoms at 160 (SN-5).
        #expect(workspace.frame("node-1") == rc(10, 10, 175, 150))
        workspace.endDrag()
        #expect(workspace.undoActionName == "Undo Resize")
    }

    private func resizeTwentyLayers() {
        var workspace = DesignFixtures.crowd
        // Frame 1's first 20 rectangles, node-2 to node-21: their box is (12, 12)–(168, 68).
        let ids = (2...21).map { "node-\($0)" }
        workspace.selectItem(ids[0])
        for id in ids.dropFirst() { workspace.toggleSelection(id) }
        #expect(workspace.selectedNodeIDs == ids)
        #expect(workspace.boxHandle(at: pt(168, 68)) == .bottomRight)
        let (_, steps) = Self.timeSteps(
            "QD-S3 resize step, 20 layers, on crowd", on: &workspace, from: pt(168, 68),
            ends: [pt(188, 68), pt(178, 68)])
        #expect(steps == 200, "the timed resizes ran \(steps) steps, not 200")
        #expect(workspace.gesture?.route == .resizeSeveral(ids, .bottomRight))
        #expect(workspace.selectionBounds?.maxX == 178, "the box didn't follow the last step")
        #expect(workspace.frame("node-21") != rc(132, 52, 16, 16), "the box's last layer didn't scale")
        workspace.endDrag()
        #expect(workspace.undoActionName == "Undo Resize")
    }

    @Test func marqueeStep() throws {
        var workspace = DesignFixtures.crowd
        // (1255, 830) is Frame 40's background (node-1951, 1235 810 160 150), the last frame, so
        // finding its children walks the 39 frames before it and their 1,911 layers.
        #expect(workspace.hitTest(pt(1255, 830)) == "node-1951")
        // Each step expands the ancestors of every picked layer in one walk of the page (#2695).
        let steps = Self.timeSteps(
            "QD-S4 marquee step on crowd", on: &workspace, from: pt(1255, 830),
            ends: [pt(1395, 960), pt(1300, 900)]).steps
        #expect(steps == 200, "the timed marquees ran \(steps) steps, not 200")
        #expect(workspace.gesture?.route == .marquee("node-1951"))
        let rect = rc(1255, 830, 45, 70)
        #expect(workspace.marquee == rect)
        let page = try #require(workspace.selectedPage)
        let expected = LiveMarquee().layers(touching: rect, in: "node-1951", on: page)
        #expect(!expected.isEmpty)
        #expect(workspace.selectedNodeIDs == expected)
        workspace.endDrag()
        #expect(workspace.history.undo.isEmpty)
    }

    /// The first 1,500 of `crowd`'s non-frame layers (a frame is every 50th id from node-1), back to front.
    private static let bulkIDs = (1...2000).filter { ($0 - 1) % 50 != 0 }.prefix(1500).map { "node-\($0)" }

    @Test func selectFifteenHundred() throws {
        let crowd = DesignFixtures.crowd
        var workspace = crowd
        let gate = DesignBudget.linuxDebugGate(device: .milliseconds(25))
        let params = JSONValue.object(["ids": .array(Self.bulkIDs.map(JSONValue.string))])
        var runs = 0
        let report = DesignBudget.expect("edit.select of 1,500 ids on crowd", runs: 5, gate: gate) {
            workspace = crowd
            _ = try? DesignWorkspace.catalog.run("edit.select", params: params, on: &workspace)
            runs += 1
        }
        #expect(report.median <= gate, "edit.select of 1,500 ids: \(report), median over the gate \(gate)")
        #expect(runs == 5)
        #expect(workspace.selectedNodeIDs == Self.bulkIDs)
        #expect(workspace.isExpanded("node-1") && workspace.isExpanded("node-1501"))
    }

    @Test func duplicateFifteenHundred() throws {
        var selected = DesignFixtures.crowd
        try selected.select(Self.bulkIDs)
        var workspace = selected
        let gate = DesignBudget.linuxDebugGate(device: .milliseconds(50))
        let report = DesignBudget.expect("edit.duplicate of 1,500 layers on crowd", runs: 5, gate: gate) {
            workspace = selected
            _ = try? DesignWorkspace.catalog.run("edit.duplicate", params: .object([:]), on: &workspace)
        }
        #expect(report.median <= gate, "edit.duplicate of 1,500 layers: \(report), median over the gate \(gate)")
        #expect(workspace.selectedNodeIDs.count == 1500)
        #expect(Set(workspace.selectedNodeIDs).isDisjoint(with: Self.bulkIDs))
        #expect(workspace.undoActionName == "Undo Duplicate")
    }

    /// The inspector re-reads the selection's lock and the layer row toggles on every drag step
    /// (it watches the live copy), so each read on crowd must walk the page once, not rebuild it.
    @Test func lockAndHideReadsPerStep() {
        var workspace = DesignFixtures.crowd
        workspace.selectItem("node-2000")
        let gate = DesignBudget.linuxDebugGate(device: .microseconds(400))
        var reads = 0
        let report = DesignBudget.expect("inspector lock and hide reads on crowd", runs: 200, gate: gate) {
            if workspace.transformHelp == nil, !workspace.isHiddenInTree("node-2000"),
               workspace.layerToggles("node-2000").count == 2 { reads += 1 }
        }
        #expect(reads == 200, "the timed reads saw a lock, a hidden layer or no toggles")
        #expect(report.median <= gate, "lock and hide reads: \(report), median over the gate \(gate)")
        #expect(report.p95 <= gate, "lock and hide reads: \(report), p95 over the gate \(gate)")
    }
}
