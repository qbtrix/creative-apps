// DesignLiveDragTests.swift: the live drag box (DesignLiveDrag, design-window
// D0-8a) on the real window. A 120-sample drag of A on `cards` leaves the
// window's workspace untouched until mouse-up while the live copy moves, and
// mouse-up lands it as one Move step with the copy cleared. A scrub's previews
// change only the copy and its end commits one Change Opacity step. The window
// is hosted off screen through the render-budget harness; it reads
// DesignWindow.lastWorkspace, a static, so it is nested in BodyCountSuites,
// which runs those suites one at a time. On `cards`, A is node-2 at
// (100, 100, 100 × 80) on a 1440 × 1024 page. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignLiveDragTests {
        /// `cards` on the fake services.
        static func cards() -> DesignWorkspace {
            var workspace = DesignFixtures.cards
            workspace.useServices(.fake)
            return workspace
        }

        static let a = DesignRect(x: 100, y: 100, width: 100, height: 80)

        @Test(.timeLimit(.minutes(2))) func aDragMovesOnlyTheCopyUntilMouseUp() async throws {
            #if DEBUG
            let live = DesignLiveDrag()
            let w = RenderBudgetWindow(DesignWindow(seed: Self.cards(), live: live))
            defer { w.close() }
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas"), "no canvas")
            let page = CGSize(width: 1440, height: 1024)
            DesignWindow.lastWorkspace = nil
            try await w.drag(from: w.point(CGPoint(x: 150, y: 140), on: page, in: board), release: false) {
                w.point(CGPoint(x: 150 + Double($0), y: 140 + Double($0) / 2), on: page, in: board)
            }
            try await w.settle(100)
            let during = try #require(DesignWindow.lastWorkspace, "the drag never reached the window")
            #expect(during.selectedNode?.id == "node-2")
            #expect(during.selectedNode?.frame == Self.a)
            #expect(!during.canUndo)
            var copy = try #require(live.workspace, "nothing is live during the drag")
            let moved = try #require(copy.selectedNode?.frame)
            #expect(moved.x > Self.a.x && moved.y > Self.a.y)

            w.send(.leftMouseUp, at: w.point(CGPoint(x: 270, y: 200), on: page, in: board))
            try await w.settle(100)
            var after = try #require(DesignWindow.lastWorkspace)
            copy.endDrag()
            #expect(after == copy)
            #expect(after.selectedNode?.frame == moved)
            #expect(after.undoActionName == "Undo Move")
            after.undo()
            #expect(!after.canUndo)
            #expect(live.workspace == nil)
            #endif
        }

        @Test func aScrubPreviewsOnlyTheCopyAndCommitsOneStep() throws {
            var model = Self.cards()
            model.selectItem("node-2")
            let live = DesignLiveDrag()
            live.begin(from: model)
            for value in stride(from: 0.9, through: 0.3, by: -0.1) { live.preview(.opacity(value)) }
            #expect(model.selectedNode?.opacity == 1)
            let shown = try #require(live.workspace?.selectedNode?.opacity)
            #expect(abs(shown - 0.3) < 1e-9)

            #expect(live.end(into: &model) == nil)
            #expect(abs((model.selectedNode?.opacity ?? 0) - 0.3) < 1e-9)
            #expect(model.undoActionName == "Undo Change Opacity")
            model.undo()
            #expect(!model.canUndo)
            #expect(live.workspace == nil)
        }
    }
}
#endif
