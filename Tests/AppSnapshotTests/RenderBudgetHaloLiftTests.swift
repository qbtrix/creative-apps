// RenderBudgetHaloLiftTests.swift: a lifted viewer drag (HaloDrawLift,
// HaloLiftedLayers) on the real-size `huge` fixture (2,000 layers, every
// property keyed), render contract rules 3 and 6. HaloLiveLayers is hosted
// with a HaloLiveEdit and fed the drag's samples the way HaloViewerGestures
// writes them (`lift` once, then the project with the moved drag), one per
// 1/120 s, each a timed layout and display; no synthetic events, which a
// hosted window doesn't get on every Mac. `liftedDrag` gates it: the samples
// draw no layer (HaloCanvasDraws stays put while HaloLiftOffset re-runs per
// sample), mouse-up draws the moved frame once, and a sample's p95 is at or
// under 8 ms (16 ms hard; render contract rule 6). `liftMatchesTheOffsetList`
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
            try #require(live.lift?.below.items.count == 1999, "huge didn't lift its top layer")
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
            expectP95(step, atMost: 8, target: 8.3)
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
