// DesignTimelineSnapshots.swift: Design's timeline slot (one-document OD-12). A still document shows no slot; one
// keyed layer slides it in under the canvas with one lane and the transport; `animated(50)` shows 51 lanes, five
// rows tall, scrolling. Light and dark: design-timeline-{still,one,fifty}-{light,dark}.png. `slideIn` (render
// budget) opens `cards` in the window, sets the first key through `keyframe.set`, and counts bodies: the window
// once for the key, the timeline strip once for its slide-in. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing
@testable import DesignApp

@MainActor
@Suite struct DesignTimelineSnapshots {
    /// `animated(count)`, or `cards` with no keys when `count` is 0.
    static func doc(_ count: Int) -> DesignWorkspace {
        count == 0 ? DesignFixtures.cards : DesignFixtures.animated(count)
    }

    @Test func slot() throws {
        for (name, count) in [("still", 0), ("one", 1), ("fifty", 50)] {
            #expect(Self.doc(count).showsTimeline == (count > 0))
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(DesignEditor(model: Self.doc(count), zoom: 0.5),
                             name: "design-timeline-\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
            }
        }
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignTimelineTests {
        @Test(.timeLimit(.minutes(2))) func slideIn() async throws {
            #if DEBUG
            let seed = DesignFixtures.cards
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: DesignLiveDrag()))
            defer { w.close() }
            try await w.settle(800)
            try await w.settle(untilStable: { DesignWindow.bodyRuns })
            let perform = try #require(DesignWindow.lastPerform)
            let (window, strip) = (DesignWindow.bodyRuns, TimelineStrip<String>.bodyRuns)
            let id = try #require(seed.selectedPage?.nodes.first?.children.first?.id)
            perform(.adoptLive(seed.keyed(id)))
            try await w.settle(400)
            let ranWindow = DesignWindow.bodyRuns - window, ranStrip = TimelineStrip<String>.bodyRuns - strip
            print("BUDGET design timeline slide-in on cards: window bodies \(ranWindow) | strip bodies \(ranStrip)")
            #expect(DesignWindow.lastWorkspace?.showsTimeline == true)
            #expect(ranWindow == 1, "the first key runs the window once: \(ranWindow)")
            #expect(ranStrip >= 1 && ranStrip <= 2, "the strip builds once as it slides in: \(ranStrip)")
            #endif
        }
    }
}

private extension DesignWorkspace {
    /// This workspace with one x key on `id` at frame 0.
    func keyed(_ id: String) -> DesignWorkspace {
        var keyed = self
        try? keyed.setKey(id, .x, at: 0, to: 0)
        return keyed
    }
}
#endif
