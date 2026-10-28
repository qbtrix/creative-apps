// RenderBudgetShellTests.swift: slice 0 of the AppKit window shell spike, measured
// on the real window (paw-workspace docs/design/drafts/2026-10-27-appkit-window-shell.md,
// section 4). The gallery's `shell` page is hosted off screen through the
// render-budget harness; its body count lives in the page's own ShellSpikeModel,
// not a static, so this suite reads only its window and needs no BodyCountSuites
// (lesson 345). The sidebar divider is dragged 120 samples through
// NSSplitView.setPosition, as the harness drags every divider, and the toggles
// run through the controller's actions, never an AX press (lesson 346). Gated:
// 0 page bodies and at most 2 root hosting layout passes per step. The step
// p95 is printed in the RENDER-BUDGET line for the spike's report; the
// supervisor lists a timing test in Tests/perf-suites.txt if it should gate.
// macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor @Suite struct RenderBudgetShellTests {
    @Test(.timeLimit(.minutes(2))) func dividerDragRunsNoPageBodyAndAtMostTwoLayoutsPerStep() async throws {
        // not-timing: the step p95 is printed for the spike's report, never asserted here.
        let model = ShellSpikeModel()
        let w = RenderBudgetWindow(GalleryShellPage(model: model))
        defer { w.close() }
        let bodies = { () -> Int? in model.rootBodies }
        try await w.settle(untilStable: bodies)
        let controller = try #require(model.controller, "the representable never handed the model its controller")
        #expect(controller.splitViewItems.count == 3)
        for id in ["suite.sidebar", "suite.canvas", "suite.inspector"] {
            #expect(await w.element(id) != nil, "no \(id) in the hosted shell")
        }
        #expect(model.rootBodies >= 1, "the page never ran")

        let step = try await w.measure("shell sidebar divider drag, 120 samples", bodies: bodies) {
            let (before, after) = try await w.dragDivider(0, of: controller.splitView, by: 80)
            #expect(after < before, "the divider didn't move the content pane (\(before) -> \(after))")
        }
        expectBodies(step, atMost: 0, target: 0)
        #expect(step.layouts <= 2 * step.steps, "\(step): more than 2 root hosting layout passes per step")
    }

    @Test(.timeLimit(.minutes(2))) func togglesCollapseTheirItemsWithoutAPageBody() async throws {
        let model = ShellSpikeModel()
        let w = RenderBudgetWindow(GalleryShellPage(model: model))
        defer { w.close() }
        let bodies = { () -> Int? in model.rootBodies }
        try await w.settle(untilStable: bodies)
        let controller = try #require(model.controller)
        let sidebar = controller.splitViewItems[0], inspector = controller.splitViewItems[2]
        #expect(!sidebar.isCollapsed && !inspector.isCollapsed)

        let step = try await w.measure("shell sidebar and inspector toggles, 4 clicks", bodies: bodies) {
            try await w.ticks(4) { i in
                if i % 2 == 1 { model.toggleSidebar() } else { model.toggleInspector() }
            }
            try await w.settle(600)
        }
        #expect(sidebar.isCollapsed && inspector.isCollapsed, "the toggles didn't collapse both items")
        expectBodies(step, atMost: 0, target: 0)
        model.toggleSidebar()
        model.toggleInspector()
        try await w.settle(600)
        #expect(!sidebar.isCollapsed && !inspector.isCollapsed, "the toggles didn't bring both items back")
    }
}
#endif
