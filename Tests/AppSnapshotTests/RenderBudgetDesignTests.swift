// RenderBudgetDesignTests.swift: Design's render budget
// (Tests/render-budgets.md) on the real window, through the harness
// (RenderBudgetHarness.swift). It opens the `crowd` fixture (2,000 layers)
// from a file, as File > Open does, then drags a rectangle 120 samples and
// draws a 120-sample marquee from an empty corner of the page. `bodies` gates
// design-window DW-b's bound (the window body runs at most 3 times over a
// 120-sample drag) and OD-18's: a canvas drag leaves the inspector rows it can't
// change (Opacity, Corners, Stroke, Fill) alone, so they run only at the press
// and the release (`inspectorRuns`), never per sample; `timing` (Tests/perf-suites.txt, report-only) judges the
// step times, and an Option-drag of Rectangle 1 on `crowd` (copy-group #6198) in the same window,
// Option held through `DesignModifiers.held` since a test's events can't hold it, must end as one copy. Before each drag the window settles until its body count stops
// moving (BodyCountSuites' `settle(untilStable:)`), so the bodies counted are
// the drag's alone, not the open's late layouts on a slow runner (#1974). Nested in BodyCountSuites, as every suite that reads a body
// counter is. `openCrowdLands` and `timing` also open crowd.design into an
// empty window (files-history P4): the "Opening <name>…" note shows before the
// file lands, and no step or layout of the open blocks over 3 refreshes. macOS only.
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
            // Copy-group: an Option-drag on 2,000 layers is a drag too, 3 editor runs at most.
            expectBodies(try await Self.optionDrag(), atMost: 3, target: 3)
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
            let option = try await Self.optionDrag()
            // Real time: p95 within one 120 Hz frame, 8 ms. Release: 6.6-7.75 ms at load 12, its press copies once.
            expectP95(option, atMost: 8, target: 8.3)
            // #6281: the press and the copy's first sample each fit two 60 Hz frames; the press on the
            // selection is quiet, so the window doesn't run until mouse-up.
            #expect(option.opening <= 33, "\(option) (budget 33 ms for the press and the first sample, #6281)")
            // files-history P4: opening crowd.design says "Opening…" in the command's own step (QB-L9, 100 ms)
            // and no step of the open, its landing included, blocks the main thread over 3 refreshes.
            let open = try await Self.openCrowd()
            #expect(open.landed, "crowd.design never landed: \(open.step)")
            #expect(open.step.opening <= 100, "\(open.step) (QB-L9: \"Opening…\" shows within 100 ms of the command)")
            // Release at load 5: slowest 31.7-45.6 ms, landing layout 26-38 ms (sync open was 207-338 ms).
            // Budget 3 refreshes, 50 ms; QB-L12's 2 refreshes, 33 ms, is the target (#6306).
            #expect(open.step.slowest <= 50, "\(open.step) (budget 50 ms, QB-L12 target 33 ms, #6306)")
            #expect(open.landing <= 50, "the landing's longest layout took \(open.landing) ms (budget 50 ms, target 33 ms, #6306)")
        }

        /// files-history P4 in the real window (QD-S11, QB-L9): an empty window opens `crowd.design` (2,000 layers)
        /// as Finder or Recents hands it over. Before it lands the status line shows "Opening <name>…";
        /// the file is read and decoded off the main thread and lands a few ticks later with all its pages.
        @Test(.timeLimit(.minutes(2))) func openCrowdLands() async throws {
            #if DEBUG
            let open = try await Self.openCrowd()
            #expect(open.progress?.hasPrefix("Opening crowd-") == true, "the open showed \(open.progress ?? "no note")")
            #expect(open.landed, "crowd.design never landed in the window: \(open.step)")
            #endif
        }

        /// Opens crowd.design in an empty window, one tick per 1/120 s until it lands (at most 2 s): the steps,
        /// the first status note shown before the landing, whether the file landed, and the longest layout pass.
        static func openCrowd() async throws -> (step: RenderStep, progress: String?, landed: Bool, landing: Double) {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("crowd-\(UUID()).design")
            try DesignFixtures.crowd.fileData().write(to: file)
            defer { try? FileManager.default.removeItem(at: file) }
            DesignWindow.openFile = nil
            DesignWindow.lastWorkspace = nil
            let w = RenderBudgetWindow(DesignWindow())
            defer { w.close() }
            try await w.settle(500)
            let open = try #require(DesignWindow.openFile, "the window never started")
            // lastWorkspace is a debug hook; the release timing builds with -DDEBUG to read it too.
            let landed = { DesignWindow.lastWorkspace?.documentURL == file }
            var progress: String?
            w.host.longestLayout = 0
            let step = try await w.measure("design open crowd.design (2,000 layers)", bodies: { nil }) {
                try await w.ticks(1) { _ in open(file) }
                var waits = 0
                while !landed(), waits < 240 {
                    if progress == nil { progress = w.value(DesignControlID.statusNote) }  // a Text's words are its value
                    waits += 1
                    try await w.ticks(1) { _ in }
                }
                // The landing's own layout runs on the tick after the document changes.
                try await w.ticks(2) { _ in }
            }
            print("design open crowd.design: longest layout \(w.host.longestLayout) ms")
            return (step, progress, landed() && DesignWindow.lastWorkspace?.pages == DesignFixtures.crowd.pages,
                    w.host.longestLayout)
        }

        /// A 120-sample Option-drag of Rectangle 1 on `crowd` in the real window: the press copies it, the
        /// samples move the copy. Option is held through `DesignModifiers.held`, since a test's events can't.
        static func optionDrag() async throws -> RenderStep {
            var crowd = BodyCountSuites.DesignWindowDragTests.Gesture.move.seed
            crowd.selectItem("node-2")
            let w = RenderBudgetWindow(DesignWindow(seed: crowd))
            defer { w.close() }
            DesignModifiers.held = .option
            defer { DesignModifiers.held = [] }
            let step = try await BodyCountSuites.DesignWindowDragTests.dragSamples(.move, in: w)
            // lastWorkspace is a debug hook; the release timing builds with -DDEBUG to check it too.
            #if DEBUG
            let after = try #require(DesignWindow.lastWorkspace, "the Option-drag never reached the window")
            #expect(after.undoActionName == "Undo Duplicate", "the Option-drag left \(after.undoActionName)")
            #expect(after.selectedNode?.name == "Rectangle 1" && after.selectedNodeID != "node-2")
            let original = after.selectedPage?.nodes.first?.children.first { $0.id == "node-2" }
            #expect(original?.frame == DesignRect(x: 12, y: 12, width: 16, height: 16), "the Option-drag moved the original")
            #expect((after.selectedNode?.frame.x ?? 0) > 12, "the copy never moved")
            #endif
            return step
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
