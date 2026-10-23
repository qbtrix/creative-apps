// RenderBudgetDesignSnapTests.swift: the smart guides on the real window (snapping SN-7). On
// `cards`, A (node-2, 100 100 100 × 80) dragged by its middle until its right edge sits on B's
// left (x 300): mid-drag `design.canvas.guides` reads the live copy's guides ("x 300 ...") while
// the window's A hasn't moved; after the release it keeps the last summary, and a new press clears
// it to "none". `snappedDrag` gates the bound on the live guides (SN-11): on `crowd`, a 120-sample
// move, resize and draw each run DesignEditor's body 3 times or fewer, and after 60 samples of each
// `design.canvas.guides` reads the live copy's summary while the window's page is as the press
// left it (a draw's press adds its layer at no size). Nested
// in BodyCountSuites, as every suite that reads a body counter or DesignWindow.lastWorkspace is.
// macOS debug builds only: DesignWindow.lastWorkspace exists only there.
#if canImport(AppKit) && DEBUG
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

        @Test(.timeLimit(.minutes(3))) func snappedDrag() async throws {
            for gesture in [DesignWindowDragTests.Gesture.move, .resize, .draw] {
                let live = DesignLiveDrag()
                let w = RenderBudgetWindow(DesignWindow(seed: gesture.seed, live: live))
                defer { w.close() }
                let step = try await Self.snappedSamples(gesture, in: w, live: live)
                #expect((step.bodies ?? 0) >= 1, "the snapped \(gesture) never reached the window: \(step)")
                expectBodies(step, atMost: 3, target: 3)
            }
        }

        /// DesignWindowDragTests' 120-sample `gesture` on the window `w` hosts, paused after 60 samples
        /// to check that the guides read the live copy's summary while the window's page hasn't moved.
        static func snappedSamples<V: View>(
            _ gesture: DesignWindowDragTests.Gesture, in w: RenderBudgetWindow<V>, live: DesignLiveDrag
        ) async throws -> RenderStep {
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas"), "no canvas")
            let start = w.point(gesture.from, on: page, in: board)
            let end = w.point(
                CGPoint(x: gesture.from.x + gesture.by.dx, y: gesture.from.y + gesture.by.dy), on: page, in: board)
            let at = { (i: Int) in
                CGPoint(x: start.x + (end.x - start.x) * Double(i) / 120, y: start.y + (end.y - start.y) * Double(i) / 120)
            }
            DesignWindow.lastWorkspace = nil
            let name = "design snapped \(gesture.rawValue), 120 samples"
            return try await w.measure(name, bodies: DesignWindowDragTests.editorBodies) {
                try await w.drag(from: start, samples: 60, release: false, path: at)
                try await w.settle(100)
                let copy = try #require(live.workspace, "nothing is live during the \(gesture)")
                let guides = try #require(copy.snapGuides, "the live \(gesture) runs no snapping gesture")
                #expect(Self.value(in: w.host) == DesignGuideOverlay.value(guides, last: nil),
                        "mid-\(gesture) the guides don't read the live copy's \(guides.summary)")
                let window = try #require(DesignWindow.lastWorkspace, "the \(gesture) never reached the window")
                // The press goes to the window (D0-8a): a draw's adds its layer there at no size. A
                // screen point maps back to the page only to within a point (CI's runner landed the
                // draw's press at y 1011 for 1010), so the press is replayed where the window put the
                // layer it added; a sample that reached the window would still change that layer's size.
                let seedIDs = Set(gesture.seed.selectedPage?.nodes.map(\.id) ?? [])
                let added = window.selectedPage?.nodes.first { !seedIDs.contains($0.id) }
                let press = added.map { DesignPoint(x: $0.frame.x, y: $0.frame.y) } ?? DesignPoint(gesture.from)
                var pressed = gesture.seed
                pressed.drag(from: press, to: press)
                #expect(window.selectedPage == pressed.selectedPage, "a sample reached the window's page mid-\(gesture)")
                try await w.ticks(60) { w.send(.leftMouseDragged, at: at(60 + $0)) }
                w.timed { w.send(.leftMouseUp, at: at(120)) }
            }
        }

        /// What the guides element under `element` reads, searched depth first: its accessibility
        /// value, else its label, which carries the same words because AppKit hands SwiftUI's value
        /// on a plain element back as nil (#262).
        static func value(in element: Any, depth: Int = 0) -> String? {
            let node = element as AnyObject
            if (node.accessibilityIdentifier?() ?? nil) == DesignControlID.canvasGuides {
                let value: Any?? = node.accessibilityValue?()
                return (value ?? nil) as? String ?? (node.accessibilityLabel?() ?? nil)
            }
            guard depth < 60 else { return nil }
            return ((node.accessibilityChildren?() ?? nil) ?? []).lazy.compactMap { value(in: $0, depth: depth + 1) }.first
        }
    }
}
#endif
