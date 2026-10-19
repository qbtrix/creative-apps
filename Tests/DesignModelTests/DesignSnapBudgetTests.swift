// DesignSnapBudgetTests.swift: QD-S13 engine build (≤ 2 ms device) and QD-S14 snapped move step
// (≤ 0.2 ms) on `crowd` and 2,000 rectangles; rows over their gate are known issues (gap #3180).
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

    /// Times 200 move steps of node-1 from `start`, alternating between `ends`, after the untimed
    /// press; checks they all ran on a move whose engine was built once.
    func timeSteps(_ name: String, _ workspace: inout DesignWorkspace, from start: DesignPoint,
                   ends: [DesignPoint], sourceLocation: SourceLocation = #_sourceLocation) {
        workspace.selectItem("node-1")
        workspace.drag(from: start, to: ends[0])
        var step = 0
        let gate = DesignBudget.linuxDebugGate(device: .microseconds(200))
        DesignBudget.expect(name, runs: 200, gate: gate, sourceLocation: sourceLocation) {
            workspace.drag(from: start, to: ends[step % 2])
            step += 1
        }
        #expect(step == 200 && workspace.gesture?.route == .move("node-1"), sourceLocation: sourceLocation)
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
}
