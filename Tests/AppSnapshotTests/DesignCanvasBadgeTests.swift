// DesignCanvasBadgeTests.swift: the size badge on the real window (design-window D0-9d). On
// `cards` with A (node-2, 100 100 100 × 80) selected, 60 of 120 samples of a drag on A's
// bottom-right handle leave the window's A at its size while the badge (`design.canvas.badge`)
// reads the live copy's size; the release lands that size. A 120-sample drag with the badge
// showing still runs DesignEditor's body 3 times or fewer (D0-8b's `dragSamples`). The window
// is hosted off screen through the render-budget harness; it reads DesignWindow.lastWorkspace
// and DesignEditor.bodyRuns, statics, so the suite nests in BodyCountSuites. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignCanvasBadgeTests {
        /// `cards` on the fake services with A selected.
        static func seed() -> DesignWorkspace {
            var workspace = DesignFixtures.cards
            workspace.useServices(.fake)
            workspace.selectItem("node-2")
            return workspace
        }

        static let page = CGSize(width: 1440, height: 1024)

        @Test(.timeLimit(.minutes(2))) func theBadgeReadsTheLiveBoxMidDrag() async throws {
            #if DEBUG
            let live = DesignLiveDrag()
            let w = RenderBudgetWindow(DesignWindow(seed: Self.seed(), live: live))
            defer { w.close() }
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            #expect(Self.label(DesignControlID.canvasBadge, in: w.host) == "100 × 80")
            // The bottom-right handle at (200, 180), dragged one point right and half a point down per sample.
            let at = { (i: Int) in w.point(CGPoint(x: 200 + Double(i), y: 180 + Double(i) / 2), on: Self.page, in: board) }
            DesignWindow.lastWorkspace = nil
            try await w.drag(from: at(0), samples: 60, release: false, path: at)
            try await w.settle(100)
            let copy = try #require(live.workspace, "nothing is live during the drag")
            let shown = try #require(Self.label(DesignControlID.canvasBadge, in: w.host), "no badge mid-drag")
            #expect(shown == copy.selectionBadge)
            #expect(shown != "100 × 80", "the badge kept A's size mid-drag")
            let during = try #require(DesignWindow.lastWorkspace, "the drag never reached the window")
            #expect(during.selectedNode?.frame == DesignRect(x: 100, y: 100, width: 100, height: 80))

            try await w.ticks(60) { w.send(.leftMouseDragged, at: at(60 + $0)) }
            w.send(.leftMouseUp, at: at(120))
            try await w.settle(100)
            let after = try #require(DesignWindow.lastWorkspace)
            #expect(live.workspace == nil)
            #expect(Self.label(DesignControlID.canvasBadge, in: w.host) == after.selectionBadge)
            #expect(after.selectionBadge != "100 × 80")
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func aDragWithTheBadgeRunsTheEditorAtMostThreeTimes() async throws {
            #if DEBUG
            let w = RenderBudgetWindow(DesignWindow(seed: Self.seed()))
            defer { w.close() }
            // `.resize` presses at (170, 160), inside A: a move of A, the badge reading X and Y.
            let step = try await DesignWindowDragTests.dragSamples(.resize, in: w)
            #expect((step.bodies ?? 0) >= 1, "the drag never reached the window: \(step)")
            expectBodies(step, atMost: 3, target: 3)
            #endif
        }

        /// The badge hangs clear of the bottom-middle handle, so the pill never sits on the grab square.
        @Test(.timeLimit(.minutes(2))) func theBadgeClearsTheBottomHandles() async throws {
            let w = RenderBudgetWindow(DesignWindow(seed: Self.seed()))
            defer { w.close() }
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            let badge = try #require(await w.element(DesignControlID.canvasBadge), "no badge")
            // A's bottom edge is y 180 on the page; window coordinates run y up.
            let edge = w.point(CGPoint(x: 150, y: 180), on: Self.page, in: board).y
            let handleBottom = edge - SuiteSize.selectionHandle / 2
            #expect(badge.maxY <= handleBottom - SuiteSpacing.xxs, "badge top \(badge.maxY), handle bottom \(handleBottom)")
        }

        /// The accessibility label of the first element called `identifier` under `element`, in tree order.
        static func label(_ identifier: String, in element: Any, depth: Int = 0) -> String? {
            let node = element as AnyObject
            if (node.accessibilityIdentifier?() ?? nil) == identifier { return node.accessibilityLabel?() ?? nil }
            guard depth < 60 else { return nil }
            for child in (node.accessibilityChildren?() ?? nil) ?? [] {
                if let found = label(identifier, in: child, depth: depth + 1) { return found }
            }
            return nil
        }
    }
}
#endif
