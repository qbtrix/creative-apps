// DesignTimelineSnapshots.swift: Design's timeline slot (one-document OD-12). A still document shows no slot; one
// keyed layer slides it in under the canvas with one lane and the transport; `animated(50)` shows 51 lanes, five
// rows tall, scrolling. Light and dark: design-timeline-{still,one,fifty}-{light,dark}.png. `slideIn` (render
// budget) opens `cards` in the window, adopts a copy with one key, and counts bodies: at most 2 window and 3
// strip bodies (the measured numbers); then 30 ruler scrub steps run the window 0 times and land frame 30 as
// the playhead once the drag rests, with no undo step or unsaved change. macOS only.
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
    @Test func slot() throws {
        for (name, doc) in [("still", DesignFixtures.cards), ("one", DesignFixtures.animated(1)), ("fifty", DesignFixtures.animated(50))] {
            #expect(doc.showsTimeline == (name != "still"))
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(DesignEditor(model: doc, zoom: 0.5),
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
            #expect(ranWindow <= 2, "the first key runs the window at most twice (measured 2): \(ranWindow)")
            #expect(ranStrip >= 1 && ranStrip <= 3, "the strip builds as it slides in (measured 3): \(ranStrip)")

            // A ruler drag: 30 scrub steps run the canvas and the strip, never the window, then land once as the
            // playhead with no undo step or unsaved change.
            perform(.pause)  // nothing plays: it only records the window's workspace
            let pre = try #require(DesignWindow.lastWorkspace)
            let beforeScrub = DesignWindow.bodyRuns
            for frame in 1...30 {
                perform(.scrub(frame)); w.host.layoutSubtreeIfNeeded(); w.window.displayIfNeeded()
            }
            let scrubRan = DesignWindow.bodyRuns - beforeScrub
            try await w.settle(400)
            perform(.pause)
            let landed = try #require(DesignWindow.lastWorkspace)
            print("BUDGET design timeline scrub, 30 steps: window bodies \(scrubRan) | landed \(landed.playhead.map(String.init) ?? "nil")")
            #expect(scrubRan == 0, "a scrub step ran the window: \(scrubRan)")
            #expect(landed.playhead == 30)
            #expect(landed.canUndo == pre.canUndo && landed.isDirty == pre.isDirty && landed.selectedPage == pre.selectedPage)
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
