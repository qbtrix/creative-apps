// RenderBudgetDesignTests.swift: Design's render budget
// (Tests/render-budgets.md) on the real window, through the harness
// (RenderBudgetHarness.swift). It opens the `crowd` fixture (2,000 layers)
// from a file, as File > Open does, then drags a rectangle 120 samples and
// draws a 120-sample marquee from an empty corner of the page. `bodies` gates
// design-window DW-b's bound (the window body runs at most 3 times over a
// 120-sample drag) and OD-18's: a canvas drag leaves the inspector rows it can't
// change (Opacity, Corners, Stroke, Fill) alone, so they run only at the press
// and the release (`inspectorRuns`), never per sample; `timing` (Tests/perf-suites.txt, report-only) judges the
// step times. Before each drag the window settles until its body count stops
// moving (BodyCountSuites' `settle(untilStable:)`), so the bodies counted are
// the drag's alone, not the open's late layouts on a slow runner (#1974). Nested in BodyCountSuites, as every suite that reads a body
// counter is. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignTests {
        @Test(.timeLimit(.minutes(2))) func bodies() async throws {
            let (move, marquee) = try await Self.run()
            // DW-b: a 120-sample drag runs the window body at most 3 times. Target: 3.
            expectBodies(move.step, atMost: 3, target: 3)  // dev: 3
            expectBodies(marquee.step, atMost: 3, target: 3)  // dev: 3
            // OD-18: each of the 4 rows runs at the press and the release, not per sample. Target: 8.
            #if DEBUG
            #expect(move.inspectorRuns <= 8, "inspector rows ran per drag sample: \(move.inspectorRuns), \(move.step)")
            #expect(marquee.inspectorRuns <= 8, "inspector rows ran per marquee sample: \(marquee.inspectorRuns), \(marquee.step)")
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func timing() async throws {
            let (move, marquee) = try await Self.run()
            // Target: a drag sample fits one 120 Hz frame.
            expectP95(move.step, atMost: 6, target: 8.3)  // dev: 4.1 ms
            expectP95(marquee.step, atMost: 4, target: 8.3)  // dev: 2.7 ms
        }

        /// A measured canvas drag and the body runs of the inspector rows a canvas drag can't change.
        struct Drag {
            let step: RenderStep
            let inspectorRuns: Int
        }

        /// The Opacity, Corners, Stroke and Fill rows' body runs so far.
        static var inspectorRuns: Int {
            DesignOpacityRow.bodyRuns + DesignCornersSection.bodyRuns + DesignInspectorStyle.bodyRuns
                + DesignInspectorFill.bodyRuns
        }

        static func run() async throws -> (move: Drag, marquee: Drag) {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("render-budget-crowd-\(UUID()).design")
            try DesignFixtures.crowd.fileData().write(to: file)
            defer { try? FileManager.default.removeItem(at: file) }
            let w = RenderBudgetWindow(DesignWindow(launch: DesignLaunch(file: file)))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return DesignWindow.bodyRuns
                #else
                return nil
                #endif
            }
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            let page = CGSize(width: 1440, height: 1024)
            // Rectangle 1 of Frame 1 sits at (12, 12, 16, 16) on the page.
            try await w.settle(untilStable: bodies)
            var rows = inspectorRuns
            let move = try await w.measure("design drag a shape", bodies: bodies) {
                try await w.drag(from: w.point(CGPoint(x: 20, y: 20), on: page, in: board), by: CGVector(dx: 160, dy: -90))
            }
            let moveRows = inspectorRuns - rows
            // The page's bottom right corner holds no frame.
            try await w.settle(untilStable: bodies)
            rows = inspectorRuns
            let marquee = try await w.measure("design marquee select", bodies: bodies) {
                try await w.drag(
                    from: w.point(CGPoint(x: 1420, y: 1010), on: page, in: board), by: CGVector(dx: -300, dy: 240))
            }
            let marqueeRows = inspectorRuns - rows
            print("RENDER-BUDGET design inspector rows: drag \(moveRows) | marquee \(marqueeRows)")
            #expect((move.bodies ?? 1) >= 1 && (marquee.bodies ?? 1) >= 1, "a drag never reached the canvas: \(move) \(marquee)")
            return (Drag(step: move, inspectorRuns: moveRows), Drag(step: marquee, inspectorRuns: marqueeRows))
        }
    }
}
#endif
