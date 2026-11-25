// DesignAnimatedAccessTreeTests.swift: the accessibility tree XCUITest snapshots on animated(500), the live-doc
// hero's fixture (#6373, gap #6409). The real-perf journey's window check stalled after a ruler sweep; this scrubs
// the hosted window to frame 300 through its intents (a synthetic drag on the hosted ruler doesn't reach SwiftUI
// here), then gates the tree's size and walk time. macOS only.
#if canImport(AppKit)
import AppKit
@testable import DesignModel
import SwiftUI
import Testing
@testable import DesignApp

@MainActor @Suite struct DesignAnimatedAccessTreeTests {
    /// Nodes, deepest depth and walk time of the whole tree, each node once.
    static func walk(_ root: Any) -> (nodes: Int, depth: Int, ms: Double) {
        var seen = Set<ObjectIdentifier>()
        var deepest = 0
        func visit(_ element: Any, _ depth: Int) {
            let node = element as AnyObject
            guard seen.insert(ObjectIdentifier(node)).inserted else { return }
            deepest = max(deepest, depth)
            _ = node.accessibilityFrame?()
            _ = node.accessibilityIdentifier?()
            guard depth < 200 else { return }
            for child in (node.accessibilityChildren?() ?? nil) ?? [] { visit(child, depth + 1) }
        }
        let began = ContinuousClock.now
        visit(root, 0)
        let took = ContinuousClock.now - began
        return (seen.count, deepest, Double(took.components.attoseconds) / 1e15 + Double(took.components.seconds) * 1000)
    }

    @Test(.timeLimit(.minutes(2))) func aScrubDoesNotGrowTheTree() async throws {
        let seed = DesignFixtures.animated(500)
        let w = RenderBudgetWindow(DesignWindow(seed: seed, live: DesignLiveDrag()))
        defer { w.close() }
        try await w.settle(1200)
        let perform = try #require(DesignWindow.lastPerform, "the window never started")
        perform(.pause)
        try await w.settle(400)
        let before = Self.walk(w.window)
        for frame in stride(from: 10, through: 300, by: 10) {  // the sweep's frames, as the ruler sends them
            perform(.scrub(frame))
            try await w.settle(16)
        }
        try await w.settle(600)
        perform(.pause)  // records the window's workspace, so its playhead can be read
        let playhead = try #require(DesignWindow.lastWorkspace).playhead ?? -1
        #expect(playhead > 250, "the scrub left the playhead at \(playhead)")
        let after = Self.walk(w.window)
        print("AXTREE design animated(500) before \(before) after \(after) playhead \(playhead)")
        #expect(after.ms < 1000, "walking the tree after a sweep took \(after.ms) ms")
        #expect(after.nodes <= before.nodes + 50, "a scrub grew the accessibility tree: \(before) -> \(after)")
    }
}
#endif
