// RenderBudgetDesignSnapTests.swift: the smart guides on the real window (snapping SN-7). On
// `cards`, A (node-2, 100 100 100 × 80) dragged by its middle until its right edge sits on B's
// left (x 300): mid-drag `design.canvas.guides` reads the live copy's guides ("x 300 ...") while
// the window's A hasn't moved; after the release it keeps the last summary, and a new press clears
// it to "none". `snappedDrag` gates the bound: a 120-sample move on `crowd` with the guide overlay
// drawn runs DesignEditor's body 3 times or fewer. Nested in BodyCountSuites, as every suite that
// reads a body counter or DesignWindow.lastWorkspace is. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignSnapTests {
        static let page = CGSize(width: 1440, height: 1024)

        @Test(.timeLimit(.minutes(2))) func theGuidesReadTheLiveDragAndOutliveTheRelease() async throws {
            var seed = DesignFixtures.cards
            seed.useServices(.fake)
            seed.selectItem("node-2")
            let live = DesignLiveDrag()
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: live))
            defer { w.close() }
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            #expect(Self.value(in: w.host) == "none")
            // A's middle (150, 140), 100 points right over 60 samples: A's right edge lands on x 300.
            let at = { (i: Int) in w.point(CGPoint(x: 150 + Double(min(i, 60)) * 100 / 60, y: 140), on: Self.page, in: board) }
            DesignWindow.lastWorkspace = nil
            try await w.drag(from: at(0), samples: 60, release: false, path: at)
            try await w.settle(100)
            let copy = try #require(live.workspace, "nothing is live during the drag")
            let during = try #require(Self.value(in: w.host), "no \(DesignControlID.canvasGuides) mid-drag")
            #expect(during == DesignGuideOverlay.value(copy.snapGuides, last: nil))
            #expect(during.contains("x 300"), "mid-drag the guides read \(during)")
            let window = try #require(DesignWindow.lastWorkspace, "the drag never reached the window")
            #expect(window.selectedNode?.frame == DesignRect(x: 100, y: 100, width: 100, height: 80))

            w.send(.leftMouseUp, at: at(60))
            try await w.settle(100)
            #expect(live.workspace == nil)
            #expect(Self.value(in: w.host) == during, "the release dropped the last guides")

            // A new press on A, not yet moved, snaps to nothing: the kept summary goes.
            w.send(.leftMouseDown, at: at(60))
            w.send(.leftMouseDragged, at: at(60))
            try await w.settle(100)
            #expect(Self.value(in: w.host) == "none")
            w.send(.leftMouseUp, at: at(60))
        }

        @Test(.timeLimit(.minutes(2))) func snappedDrag() async throws {
            #if DEBUG
            let w = RenderBudgetWindow(DesignWindow(seed: DesignWindowDragTests.Gesture.move.seed))
            defer { w.close() }
            let step = try await DesignWindowDragTests.dragSamples(.move, in: w)
            #expect((step.bodies ?? 0) >= 1, "the drag never reached the window: \(step)")
            expectBodies(step, atMost: 3, target: 3)
            #endif
        }

        /// The accessibility value of the guides element under `element`, searched depth first.
        static func value(in element: Any, depth: Int = 0) -> String? {
            let node = element as AnyObject
            if (node.accessibilityIdentifier?() ?? nil) == DesignControlID.canvasGuides {
                let value: Any?? = node.accessibilityValue?()
                return (value ?? nil) as? String
            }
            guard depth < 60 else { return nil }
            return ((node.accessibilityChildren?() ?? nil) ?? []).lazy.compactMap { value(in: $0, depth: depth + 1) }.first
        }
    }
}
#endif
