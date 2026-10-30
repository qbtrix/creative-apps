// RenderBudgetLibraryAgentTabTests.swift (render budget row "open the
// sidebar's AI tab: 0 window bodies, 0 grid bodies"): the real Library window
// at 10,000 photos (the `large` fixture), on the render budget harness.
// Picking the sidebar's AI segment (as its click does) switches
// AgentSidebarTabs' own state, so LibraryWindow's and LibraryBrowser's
// bodies run 0 times; the tab shows its empty state. Nested in
// BodyCountSuites: it reads global body counters. Debug builds only. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryAgentTabTests {
        @Test(.timeLimit(.minutes(3))) func openingTheAITabRendersNothing() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "large"]))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return LibraryWindow.bodyRuns + LibraryBrowser.bodyRuns
                #else
                return nil
                #endif
            }
            #expect(await w.element("library.sidebar.tabs.ai") != nil, "the sidebar shows no AI tab")
            try await w.settle(untilStable: bodies, turns: 8)
            let step = try await w.measure("library sidebar AI tab, large", bodies: bodies) {
                // A synthetic click waits in NSSegmentedControl's tracking loop; pick the segment as its click would.
                try await w.ticks(1) { _ in #expect(w.select(segment: "library.sidebar.tabs.ai"), "no AI segment") }
            }
            try await w.settle()
            #expect(await w.element("suite.agent.empty") != nil, "the AI tab didn't open")
            #expect(step.bodies == 0, "\(step)")
        }
    }
}
#endif
