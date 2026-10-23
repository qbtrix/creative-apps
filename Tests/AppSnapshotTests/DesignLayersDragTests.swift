// DesignLayersDragTests.swift: a Layers row drag on the real window
// (layers-panel L-4). On `crowd` (2,000 layers, `.fake`) with Frame 40 and
// Frame 39 expanded, the Text row of Frame 40 (node-2000, the top layer) is
// dragged down over the rows under it in 120 samples and dropped on the lower
// part of Rectangle 21 (node-1971). The insertion line is the panel's own
// state, so DesignEditor's body runs 3 times or fewer over the drag, and the
// release records one "Move Layer" step that puts Text behind Rectangle 21.
// Without autoscroll the drag hovers every row visible in the window, not 120
// distinct rows. Every press here activates the window, so the window takes
// activation clicks. DesignEditor.bodyRuns and DesignWindow.lastWorkspace are
// process-global debug state, so the suite nests in BodyCountSuites. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignLayersDragTests {
        static let frame40 = "node-1951", frame39 = "node-1901", text = "node-2000", rectangle21 = "node-1971"

        /// `crowd` on the fake services with Frame 40 and Frame 39 open in Layers.
        static func seed() throws -> DesignWorkspace {
            var workspace = DesignFixtures.crowd
            workspace.useServices(.fake)
            try workspace.setExpanded(frame40, true)
            try workspace.setExpanded(frame39, true)
            return workspace
        }

        /// Frame 40's children's ids, back to front.
        static func frame40Children(_ workspace: DesignWorkspace) -> [String] {
            (workspace.selectedPage?.nodes.first { $0.id == frame40 }?.children ?? []).map(\.id)
        }

        @Test(.timeLimit(.minutes(3)), .disabled("quarantine #3269 until 2026-10-22")) func aRowDragRunsTheEditorAtMostThreeTimesAndDropsOneStep() async throws {
            #if DEBUG
            let w = RenderBudgetWindow(DesignWindow(seed: try Self.seed()).allowsWindowActivationEvents())
            defer { w.close() }
            try await w.settle(800)
            let from = try #require(await w.element("design.layer.\(Self.text)"), "no Text row")
            let onto = try #require(await w.element("design.layer.\(Self.rectangle21)"), "no Rectangle 21 row")
            // Window coordinates point up: a fifth of the way up the target row is its bottom quarter.
            let start = CGPoint(x: from.midX, y: from.midY)
            let end = CGPoint(x: onto.midX, y: onto.minY + onto.height / 5)
            DesignWindow.lastWorkspace = nil
            let step = try await w.measure("design layers row drag, 120 samples", bodies: DesignWindowDragTests.editorBodies) {
                try await w.drag(from: start, by: CGVector(dx: end.x - start.x, dy: end.y - start.y), samples: 120)
            }
            expectBodies(step, atMost: 3, target: 3)
            try await w.settle(100)
            var after = try #require(DesignWindow.lastWorkspace, "the drop never reached the window")
            #expect(after.undoActionName == "Undo Move Layer")
            let ids = Self.frame40Children(after)
            // Back to front: Text now sits right behind Rectangle 21.
            let at = try #require(ids.firstIndex(of: Self.rectangle21))
            #expect(ids.firstIndex(of: Self.text) == at - 1)
            after.undo()
            #expect(Self.frame40Children(after).last == Self.text)
            #expect(!after.canUndo)
            #endif
        }
    }
}
#endif
