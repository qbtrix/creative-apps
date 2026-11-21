// RenderBudgetHaloLiftTests.swift: a lifted viewer drag (HaloDrawLift,
// HaloLiftedLayers) on the real-size `huge` fixture (2,000 layers, every
// property keyed), render contract rules 3 and 6. HaloLiveLayers is hosted
// with a HaloLiveEdit and fed the drag's samples the way HaloViewerGestures
// writes them (`lift` once, then the project with the moved drag), one per
// 1/120 s, each a timed layout and display. `liftedDrag` gates the draws: the
// samples draw no layer (HaloCanvasDraws stays put while HaloLiftOffset
// re-runs per sample) and mouse-up draws the moved frame once.
// `liftedDragTiming` gates a sample's p95 at or under 8 ms (16 ms hard; render
// contract rule 6); a wall-clock test, it runs where Tests/perf-suites.txt
// lists it and is disabled until it does. `liftedDragInTheWindow` feeds the
// same samples to the whole HaloWindow on huge and gates (DEBUG) that no
// window or inspector body re-runs per sample. `pressDragReleaseInTheWindow`
// sends a real press, 60 moves and a release to huge's viewer through hosted
// events and gates (DEBUG) that no move re-runs the window and the release
// commits one undo step; `pressDragReleaseTiming` gates each part's p95 (the
// press and release at 16 ms, a move at 8), disabled until perf-suites lists
// it. `liftMatchesTheOffsetList`
// checks the lift moved by a delta draws the pixels the offset list draws.
// Nested in BodyCountSuites, as every suite that reads a body counter is.
// macOS only.
#if canImport(AppKit)
import AppKit
@testable import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloLiftTests {
        static let samples = 120
        /// The press, in composition pixels: the middle of the frame.
        static let press = HaloPoint(x: 960, y: 540)

        @Test(.timeLimit(.minutes(4))) func liftedDrag() async throws {
            _ = try await Self.drag()
        }

        @Test(.disabled("timing: runs once Tests/perf-suites.txt lists it"), .timeLimit(.minutes(4)))
        func liftedDragTiming() async throws {
            expectP95(try await Self.drag(), atMost: 8, target: 8.3)
        }

        /// Hosts huge, lifts the pressed layer, feeds the samples and checks
        /// the draw counts (DEBUG); the samples' timing.
        static func drag() async throws -> RenderStep {
            let project = try Self.project("huge")
            let live = HaloLiveEdit()
            live.current = { project }
            let w = RenderBudgetWindow(Self.layers(project, live), size: CGSize(width: 1280, height: 760))
            defer { w.close() }
            var begun = project
            begun.beginViewerDrag(at: Self.press)
            try #require(begun.viewerDrag != nil, "the press hit no layer")
            live.lift = HaloViewerGestures.lift(project, at: Self.press)
            live.project = begun
            let lift = try #require(live.lift, "huge's pressed layer didn't lift")
            try #require(lift.below.items.count + 1 + lift.above.items.count == 2000, "the lift lost layers")
            let draws = { BodyTally.runs(of: HaloCanvasDraws.self) }
            try await w.settle(untilStable: draws)

            let offsets = BodyTally.runs(of: HaloLiftOffsetBodies.self)
            let step = try await w.measure("halo lifted viewer drag on huge, \(Self.samples) samples", bodies: draws) {
                try await w.ticks(Self.samples) { i in
                    var shown = begun
                    shown.moveViewerDrag(to: HaloPoint(x: Self.press.x + 3 * Double(i), y: Self.press.y + Double(i)))
                    live.project = shown
                }
            }
            #if DEBUG
            #expect(step.bodies == 0, "a lifted sample drew layers: \(step)")
            #expect(BodyTally.runs(of: HaloLiftOffsetBodies.self) - offsets >= Self.samples / 2, "the lift didn't move: \(step)")
            // Mouse-up: the moved frame is drawn once, the commit's one resample.
            let before = draws()
            live.project = nil
            live.lift = nil
            w.host.layoutSubtreeIfNeeded()
            w.window.displayIfNeeded()
            try await w.settle(100)
            #expect(draws() > before, "mouse-up didn't draw the frame")
            #endif
            return step
        }

        /// The same lifted samples in the whole window on huge: nothing outside
        /// the viewer re-runs, and a sample's layout stays out of the window.
        @Test(.timeLimit(.minutes(6))) func liftedDragInTheWindow() async throws {
            let project = try Self.project("huge")
            let live = HaloLiveEdit()
            let w = RenderBudgetWindow(HaloWindow(model: project, live: live), size: CGSize(width: 1700, height: 1000))
            defer { w.close() }
            try await w.settle(2000)
            var begun = live.current() ?? project
            begun.beginViewerDrag(at: Self.press)
            try #require(begun.viewerDrag != nil, "the press hit no layer")
            live.lift = HaloViewerGestures.lift(begun, at: Self.press)
            live.project = begun
            try await w.settle(1000)
            let outside = { HaloWindowPlaybackTests.windowBodies().map { $0 + BodyTally.runs(of: HaloPropertyRowView.self) } }
            let step = try await w.measure("halo lifted viewer drag in the window on huge, 60 samples", bodies: outside) {
                try await w.ticks(60) { i in
                    var shown = begun
                    shown.moveViewerDrag(to: HaloPoint(x: Self.press.x + 3 * Double(i), y: Self.press.y + Double(i)))
                    live.project = shown
                }
            }
            #if DEBUG
            #expect(step.bodies == 0, "a lifted sample re-ran the window or the inspector: \(step)")
            #endif
        }

        /// A press, drag and release on huge's viewer in the whole window,
        /// through hosted events, each timed on its own: the press (the lift
        /// and the first live frame), the drag's moves, and the release (the
        /// one commit, one undo step).
        @Test(.timeLimit(.minutes(6))) func pressDragReleaseInTheWindow() async throws {
            _ = try await Self.pressDragRelease()
        }

        @Test(.disabled("timing: runs once Tests/perf-suites.txt lists it"), .timeLimit(.minutes(6)))
        func pressDragReleaseTiming() async throws {
            let (press, drag, release) = try await Self.pressDragRelease()
            expectP95(press, atMost: 16, target: 8.3)
            expectP95(drag, atMost: 8, target: 8.3)
            expectP95(release, atMost: 16, target: 8.3)
        }

        static func pressDragRelease() async throws -> (RenderStep, RenderStep, RenderStep) {
            let project = try Self.project("huge")
            let w = RenderBudgetWindow(
                HaloWindow(model: project).environment(\.haloViewerTakesActivationClicks, true),
                size: CGSize(width: 1700, height: 1000))
            defer { w.close() }
            try await w.settle(2000)
            let canvas = try #require(await w.element("halo.viewer.canvas"), "no halo.viewer.canvas")
            let start = CGPoint(x: canvas.midX, y: canvas.midY)
            #if DEBUG
            let undo = HaloWindow.shownProject?.history.undo.count ?? 0
            #endif
            let press = try await w.measure("halo press on huge", bodies: HaloWindowPlaybackTests.windowBodies) {
                w.timed { w.send(.leftMouseDown, at: start) }
                w.timed { w.send(.leftMouseDragged, at: CGPoint(x: start.x + 1, y: start.y)) }
            }
            let drag = try await w.measure("halo drag on huge, 60 moves", bodies: HaloWindowPlaybackTests.windowBodies) {
                try await w.ticks(60) { i in w.send(.leftMouseDragged, at: CGPoint(x: start.x + 1 + Double(i), y: start.y)) }
            }
            let release = try await w.measure("halo release on huge", bodies: HaloWindowPlaybackTests.windowBodies) {
                w.timed { w.send(.leftMouseUp, at: CGPoint(x: start.x + 61, y: start.y)) }
            }
            #if DEBUG
            #expect(drag.bodies == 0, "a drag move re-ran the window: \(drag)")
            #expect(HaloWindow.shownProject?.history.undo.count == undo + 1, "the release didn't commit one step")
            #endif
            return (press, drag, release)
        }

        @Test func liftMatchesTheOffsetList() async throws {
            let project = try Self.project("keyed")
            var moved = project
            moved.beginViewerDrag(at: HaloPoint(x: 960, y: 980))
            try #require(moved.viewerDrag != nil, "the press hit no layer")
            moved.moveViewerDrag(to: HaloPoint(x: 1160, y: 900))
            // The old path: the offset list drawn whole.
            let whole = HaloLiveEdit()
            whole.project = moved
            // The lift: the resting frame in three parts, the middle one moved.
            let lifted = HaloLiveEdit()
            lifted.project = moved
            lifted.lift = HaloViewerGestures.lift(project, at: HaloPoint(x: 960, y: 980))
            try #require(lifted.lift != nil, "keyed's Floor didn't lift")
            let a = try #require(render(Self.layers(project, whole), scheme: .light))
            let b = try #require(render(Self.layers(project, lifted), scheme: .light))
            #expect(a.pixelsWide == b.pixelsWide && a.pixelsHigh == b.pixelsHigh)
            var off = 0
            for y in stride(from: 0, to: a.pixelsHigh, by: 2) {
                for x in stride(from: 0, to: a.pixelsWide, by: 2) {
                    let p = a.colorAt(x: x, y: y), q = b.colorAt(x: x, y: y)
                    if let p, let q, abs(p.redComponent - q.redComponent) + abs(p.greenComponent - q.greenComponent)
                        + abs(p.blueComponent - q.blueComponent) + abs(p.alphaComponent - q.alphaComponent) > 0.03 {
                        off += 1
                    }
                }
            }
            // Antialiased edges may differ by a level; the picture may not.
            #expect(off < a.pixelsWide * a.pixelsHigh / 4 / 500, "\(off) sampled pixels differ")
        }

        static func project(_ name: String) throws -> HaloProject {
            var project = HaloProject(services: .live)
            project.restore(try #require(HaloFixtures.project(name)))
            return project
        }

        static func layers(_ project: HaloProject, _ live: HaloLiveEdit) -> some View {
            let comp = project.selectedComposition
            return HaloLiveLayers(
                model: project, artboard: CGSize(width: comp?.width ?? 1, height: comp?.height ?? 1)
            )
            .environment(\.haloLiveEdit, live)
            .frame(width: 960, height: 560)
            .background(Color.black)
        }
    }
}
#endif
