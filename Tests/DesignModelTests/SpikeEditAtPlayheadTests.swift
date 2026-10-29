// SpikeEditAtPlayheadTests.swift: SPIKE (spike/one-document, never merged). (a) Runs Live editors on the keyed
// 50-node fixture at playhead 1 s (frame 60) and prints what the user sees after each edit against what they asked
// for. Each editor writes the rest pose (`frame`, `opacity`); a keyed axis's key wins when sampled. Asserts nothing.
import DesignModel
import SuiteKernel
import Testing

@Suite struct SpikeEditAtPlayheadTests {
    let t = 60.0
    let page = DesignFixtures.animated(50).selectedPage!

    func shown(_ nodes: [DesignNode], _ id: String) -> DesignNode? {
        var p = page; p.nodes = nodes
        return p.sampled(at: t).nodes.first?.children.first { $0.id == id } ?? p.sampled(at: t).nodes.first { $0.id == id }
    }

    @Test func editsAtPlayhead() throws {
        let before = try #require(shown(page.nodes, "node-2"))
        let other = try #require(shown(page.nodes, "node-30"))
        print("SPIKE-A at 1 s node-2 shows x \(before.frame.x) y \(before.frame.y) opacity \(before.opacity); rest x \(page.nodes[0].children[0].frame.x)")

        let moved = try LiveTransforming().move(["node-2"], by: DesignPoint(x: 100, y: 0), on: page)
        print("SPIKE-A LiveTransforming.move +100 x: shown dx \(try #require(shown(moved.nodes, "node-2")).frame.x - before.frame.x) (asked 100)")

        let nudged = try LiveTransforming().nudge(["node-2"], .right, large: true, on: page)
        print("SPIKE-A LiveTransforming.nudge right large: shown dx \(try #require(shown(nudged.nodes, "node-2")).frame.x - before.frame.x)")

        let resized = try LiveTransforming().resize(["node-2"], handle: .bottomRight, by: DesignPoint(x: 20, y: 20),
                                                    modifiers: DesignModifiers(), on: page)
        let r = try #require(shown(resized.nodes, "node-2"))
        print("SPIKE-A LiveTransforming.resize +20: shown w \(r.frame.width) (was \(before.frame.width)) x \(r.frame.x) (was \(before.frame.x))")

        let aligned = try LiveAligning().align(.left, ["node-2", "node-30"], on: page)
        let a2 = try #require(shown(aligned.nodes, "node-2")), a30 = try #require(shown(aligned.nodes, "node-30"))
        print("SPIKE-A LiveAligning.align left: shown x \(a2.frame.x) and \(a30.frame.x) (equal = right; before \(before.frame.x), \(other.frame.x))")

        var mint = DesignIDMint(taken: [], after: 1000)
        let dup = try LiveDuplicating().duplicate(["node-2"], offset: DesignPoint(x: 10, y: 10), on: page, mint: &mint)
        let copyID = try #require(dup.selection.last)
        let copy = try #require(shown(dup.nodes, copyID))
        let copyRest = dup.nodes[0].children.first { $0.id == copyID }
        print("SPIKE-A LiveDuplicating +10,+10: copy keeps time \(copyRest?.time != nil); shown offset \(copy.frame.x - before.frame.x), \(copy.frame.y - before.frame.y) (asked 10, 10)")

        let styledX = try LiveStyling().setFrame(.x, to: 500, ["node-2"], on: page)
        print("SPIKE-A LiveStyling.setFrame x 500: shown x \(try #require(shown(styledX.nodes, "node-2")).frame.x)")
        let faded = try LiveStyling().setOpacity(0.9, ["node-2"], on: page)
        print("SPIKE-A LiveStyling.setOpacity 0.9: shown opacity \(try #require(shown(faded.nodes, "node-2")).opacity)")

        var workspace = DesignFixtures.animated(50)
        let restHit = workspace.hitTest(DesignPoint(x: 52, y: 40))
        let sampledHit = workspace.hitTest(DesignPoint(x: 52, y: 40), at: t)
        print("SPIKE-A hit at (52, 40): rest \(restHit ?? "nil"), sampled at 1 s \(sampledHit ?? "nil")")
        _ = workspace.isOpen
        workspace = DesignFixtures.animated(1)
        let data = try workspace.fileData()
        print("SPIKE-A file: \(data.count) bytes for 1 keyed node; reopen keeps time \((try? LiveFiling().decode(data))?.pages.first?.nodes.first?.time != nil)")
    }
}
