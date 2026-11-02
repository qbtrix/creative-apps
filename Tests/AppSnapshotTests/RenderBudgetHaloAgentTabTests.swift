// RenderBudgetHaloAgentTabTests.swift (render budget row "open the sidebar's
// AI tab: 0 window bodies"): the real Halo window on the `crowd` fixture, on
// the render budget harness. Picking the sidebar's AI segment (as its click
// does) switches AgentSidebarTabs' own state, so HaloWindow's body, and with
// it the viewer and timeline, runs 0 times; the tab shows its
// empty state. Nested in BodyCountSuites: it reads global body counters.
// Debug builds only. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import HaloApp
@testable import HaloModel
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloAgentTabTests {
        @Test(.timeLimit(.minutes(3))) func openingTheAITabRendersNothing() async throws {
            var project = HaloProject(services: .fake)
            project.restore(try #require(HaloFixtures.project("crowd")))
            let w = RenderBudgetWindow(HaloWindow(model: project))
            defer { w.close() }
            try await w.settle(800)
            let bodies = HaloWindowPlaybackTests.windowBodies
            #expect(await w.element("halo.sidebar.tabs.ai") != nil, "the sidebar shows no AI tab")
            try await w.settle(untilStable: bodies)
            let step = try await w.measure("halo sidebar AI tab, crowd", bodies: bodies) {
                // A synthetic click waits in NSSegmentedControl's tracking loop; pick the segment as its click would.
                try await w.ticks(1) { _ in #expect(w.select(segment: "halo.sidebar.tabs.ai"), "no AI segment") }
            }
            try await w.settle()
            #expect(await w.element("suite.agent.empty") != nil, "the AI tab didn't open")
            #expect(step.bodies == 0, "\(step)")
        }
    }
}
#endif
