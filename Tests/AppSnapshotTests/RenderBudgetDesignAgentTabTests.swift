// RenderBudgetDesignAgentTabTests.swift (render budget row "open the
// sidebar's AI tab: 0 window bodies"): the real Design window seeded with the
// `crowd` fixture (2,000 layers), on the render budget harness. Picking the
// sidebar's AI segment (as its click does) switches AgentSidebarTabs' own
// state, so DesignWindow's and DesignEditor's bodies run 0 times, and with
// them the canvas; the tab shows its empty state. Nested in BodyCountSuites:
// it reads global body counters. Debug builds only. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignAgentTabTests {
        @Test(.timeLimit(.minutes(3))) func openingTheAITabRendersNothing() async throws {
            let w = RenderBudgetWindow(DesignWindow(seed: DesignFixtures.crowd))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return DesignWindow.bodyRuns + DesignEditor.bodyRuns
                #else
                return nil
                #endif
            }
            #expect(await w.element("design.sidebar.tabs.ai") != nil, "the sidebar shows no AI tab")
            try await w.settle(untilStable: bodies)
            let step = try await w.measure("design sidebar AI tab, crowd", bodies: bodies) {
                // A synthetic click waits in NSSegmentedControl's tracking loop; pick the segment as its click would.
                try await w.ticks(1) { _ in #expect(w.select(segment: "design.sidebar.tabs.ai"), "no AI segment") }
            }
            try await w.settle()
            #expect(await w.element("suite.agent.empty") != nil, "the AI tab didn't open")
            #expect(step.bodies == 0, "\(step)")
        }
    }
}
#endif
