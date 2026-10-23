// DesignSnapBudgetTests.swift: QD-S13 engine build (≤ 2 ms device) and QD-S14 snapped move, resize
// and draw steps (≤ 0.2 ms) on `crowd` and 2,000 rectangles; rows over their gate are known issues (gap #3180).
@testable import DesignModel
import Testing

@Suite struct DesignSnapBudgetTests {
    /// One page of 2,000 rectangles, node-1 to node-2000, 50 across and 40 down, 20 × 18 on a 28 × 25 grid.
    static var flat: DesignWorkspace {
        let nodes = (0..<2000).map { i in
            DesignNode(id: "node-\(i + 1)", name: "Rectangle \(i + 1)", kind: .rectangle,
                       frame: rc(10 + Double(i % 50) * 28, 10 + Double(i / 50) * 25, 20, 18))
        }
        var workspace = DesignWorkspace()
        workspace.load([DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: nodes)])
        return workspace
    }

    /// Times building the engine for a drag of node-1; returns how many candidates it held.
    func timeBuild(_ name: String, _ workspace: DesignWorkspace, runs: Int) -> Int {
        var count = 0
        DesignBudget.expect(name, runs: runs, gate: DesignBudget.linuxDebugGate(device: .milliseconds(2))) {
            count = DesignSnapIndex(workspace.snapCandidates(moving: ["node-1"], drawingInto: nil)).candidates.count
        }
        return count
    }

    @Test func engineBuild() {
        var (crowd, flat) = (0, 0)
        withKnownIssue("the kernel's candidate walk is quadratic (gap #3180)", isIntermittent: true) {
            crowd = timeBuild("QD-S13 engine build on crowd", DesignFixtures.crowd, runs: 20)
            flat = timeBuild("QD-S13 engine build on a flat page of 2,000", Self.flat, runs: 3)
        }
        // Frame 1's 39 sibling frames and the page; a rectangle's 1,999 siblings and the page.
        #expect(crowd == 40 && flat == 2000)
    }

    /// Times 200 steps of `tool` with node-1 selected from `start`, alternating between `ends`, after
    /// the untimed press; checks they all ran on `route` (a move of node-1) whose engine was built once.
    func timeSteps(_ name: String, _ workspace: inout DesignWorkspace, tool: DesignTool = .move,
                   route: DesignGesture.Route = .move("node-1"), from start: DesignPoint,
                   ends: [DesignPoint], sourceLocation: SourceLocation = #_sourceLocation) {
        workspace.selectItem("node-1")
        workspace.selectTool(tool)
        workspace.drag(from: start, to: ends[0])
        var step = 0
        let gate = DesignBudget.linuxDebugGate(device: .microseconds(200))
        DesignBudget.expect(name, runs: 200, gate: gate, sourceLocation: sourceLocation) {
            workspace.drag(from: start, to: ends[step % 2])
            step += 1
        }
        #expect(step == 200 && workspace.gesture?.route == route, sourceLocation: sourceLocation)
        #expect(workspace.gesture?.snapBuilds == 1, sourceLocation: sourceLocation)
    }

    @Test func snapStep() {
        // node-1 (10, 10) by (27.4, 0.4) and (55.6, 0.4): each snaps onto the next column's left edge.
        var flat = Self.flat
        withKnownIssue("the kernel's gap engine scans every candidate per step (gap #3180)", isIntermittent: true) {
            timeSteps("QD-S14 snapped move step on a flat page of 2,000", &flat,
                      from: pt(20, 19), ends: [pt(47.4, 19.4), pt(75.6, 19.4)])
        }
        // Outside the known issue: the 200th step ran (it ends on the second end) on one engine.
        #expect(flat.frame("node-1") == rc(66, 10, 20, 18) && flat.gesture?.snapBuilds == 1 && flat.snapGuides?.lines.isEmpty == false)

        // Frame 1 (10, 10) by (172.4, 0.4) and (177.6, 0.4) on crowd: onto Frame 2's left edge at 185.
        var crowd = DesignFixtures.crowd
        timeSteps("QD-S14 snapped move step on crowd", &crowd, from: pt(30, 30), ends: [pt(202.4, 30.4), pt(207.6, 30.4)])
        #expect(crowd.frame("node-1") == rc(185, 10, 160, 150) && (crowd.snapGuides?.summary ?? "").contains("x 185"))
    }

    @Test func snapResizeAndDrawSteps() {
        // node-1's bottom-right handle (30, 28) to (37.4, 28.4) and (65.6, 28.4): its right edge onto
        // the next columns' left edges at 38 and 66, its bottom on its row's at 28.
        var resize = Self.flat
        withKnownIssue("the kernel's gap engine scans every candidate per step (gap #3180)", isIntermittent: true) {
            timeSteps("QD-S14 snapped resize step on a flat page of 2,000", &resize,
                      route: .resize("node-1", .bottomRight, rc(10, 10, 20, 18)),
                      from: pt(30, 28), ends: [pt(37.4, 28.4), pt(65.6, 28.4)])
        }
        // Outside the known issue: the 200th step ran on one engine and landed snapped.
        #expect(resize.frame("node-1") == rc(10, 10, 56, 18) && resize.gesture?.snapBuilds == 1)
        #expect(resize.snapGuides?.lines.isEmpty == false)

        // A rectangle from (37.4, 34.6) to (65.6, 52.6) and (93.6, 52.6): the start onto (38, 35),
        // the ends onto x 66 and 94 and the second row's bottom at 53.
        var draw = Self.flat
        withKnownIssue("the kernel's gap engine scans every candidate per step (gap #3180)", isIntermittent: true) {
            timeSteps("QD-S14 snapped draw step on a flat page of 2,000", &draw, tool: .rectangle,
                      route: .draw(.rectangle), from: pt(37.4, 34.6), ends: [pt(65.6, 52.6), pt(93.6, 52.6)])
        }
        #expect(draw.selectedNode?.frame == rc(38, 35, 56, 18) && draw.gesture?.snapBuilds == 1)
        #expect(draw.snapGuides?.lines.isEmpty == false)
    }
}
