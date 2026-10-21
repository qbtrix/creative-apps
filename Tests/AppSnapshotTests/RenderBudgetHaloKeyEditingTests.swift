// RenderBudgetHaloKeyEditingTests.swift (key-editing KE-6, Quality tests,
// packet docs/blueprints/halo/features/key-editing.md): the timeline's key
// editing on the real Halo window, through the harness
// (RenderBudgetHarness.swift). On `parented` with Ball's and Rig's keys at
// frame 0 picked (picked in the Model before the window opens: the harness's
// presses carry no Shift) and the playhead scrubbed to 36 (at 0 its grab band
// covers the key, so the press scrubbed instead: #4150), Ball's key is
// dragged 120 samples right: at most 3
// window bodies (the lanes draw each step on their own layers, TL-22; the
// release sends one move and its end). On `crowd` (300 lanes, 5,000 keys) a
// press on Solid 300's bed gives the strip focus, then Select All Keys goes
// down the responder chain as ⌘A's selectAll: does (the harness has no menu
// bar to press ⌘A in), so the strip's onCommand runs `.selectAllKeys`: at
// most 1 window body. The packet's p95s (drag ≤ 8 ms, ⌘A ≤ 16 ms) are
// judged only by `timing`, which belongs in Tests/perf-suites.txt (only the
// supervisor edits it); the body tests print them. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloKeyEditingTests {
        static let ball = "comp-1-layer-2"
        static let rig = "comp-1-layer-3"
        static let solid300 = "comp-1-layer-300"

        @Test(.timeLimit(.minutes(2))) func keyDragInThreeBodies() async throws {
            let drag = try await Self.keyDrag()
            print("KEY-DRAG \(drag) | packet budget: p95 ≤ 8 ms (measured \(drag.p95) ms)")
            #expect(drag.steps >= 120, "the drag sent \(drag.steps) steps")
            // Target: 3 (the release's one move and its end, plus the pick redrawn).
            expectBodies(drag, atMost: 3, target: 3)
        }

        @Test(.timeLimit(.minutes(2))) func selectAllInOneBody() async throws {
            let all = try await Self.selectAll()
            print("SELECT-ALL-KEYS \(all) | packet budget: p95 ≤ 16 ms (measured \(all.p95) ms)")
            // A pick is one model change: one body. Target: 1.
            expectBodies(all, atMost: 1, target: 1)
        }

        @Test(.timeLimit(.minutes(4))) func timing() async throws {
            let drag = try await Self.keyDrag()
            let all = try await Self.selectAll()
            // Targets: a drag step fits one 120 Hz frame; ⌘A on 5,000 keys one 60 Hz frame.
            expectP95(drag, atMost: 8, target: 8.3)
            expectP95(all, atMost: 16, target: 16)
        }

        /// Picks Ball's and Rig's keys at 0 on `parented`, then drags Ball's key 120 samples right.
        static func keyDrag() async throws -> RenderStep {
            var project = HaloLaunch(arguments: ["Halo", "-HaloFixture", "parented"]).project()
            project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
            project.pickLaneKeys(layerID: rig, frame: 0, mode: .extend)
            // Off every key: the playhead's grab band over Ball's key at 0 would take the press (#4150).
            project.scrub(to: HaloKeyEditingSnapshots.playhead)
            #if DEBUG
            let picked = project.pickedKeyframes.count
            #endif
            #expect(
                project.pickedFrames(of: ball) == [0] && project.pickedFrames(of: rig) == [0],
                "the pick isn't Ball's and Rig's keys at 0")
            let w = RenderBudgetWindow(HaloWindow(model: project))
            defer { w.close() }
            try await w.settle(500)
            try await w.settle(untilStable: HaloWindowPlaybackTests.windowBodies)
            let key = try #require(await w.element("halo.timeline.key.\(ball).0"), "no key at 0 on Ball's lane")
            let step = try await w.measure("halo key drag, two picked keys, 120 samples", bodies: HaloWindowPlaybackTests.windowBodies) {
                try await w.drag(from: CGPoint(x: key.midX, y: key.midY), by: CGVector(dx: 120, dy: 0))
            }
            #if DEBUG
            // KE-4 moves the keys and the pick follows them; either way the drag never drops the pick.
            #expect(HaloWindow.shownProject?.pickedKeyframes.count == picked, "the drag changed the pick: \(step)")
            #endif
            return step
        }

        /// Gives the strip focus on `crowd` with a press on Solid 300's bed, then sends selectAll: as ⌘A does.
        static func selectAll() async throws -> RenderStep {
            let project = HaloLaunch(arguments: ["Halo", "-HaloFixture", "crowd"]).project()
            let w = RenderBudgetWindow(HaloWindow(model: project), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            _ = w.window.makeFirstResponder(w.host)
            try await w.settle(600)
            try await w.settle(untilStable: HaloWindowPlaybackTests.windowBodies)
            // Frame 15 of 300: on the bed, half way between the keys at 0 and 30.
            let lane = try #require(await w.element("halo.timeline.lane.\(solid300)"), "no lane for Solid 300")
            w.click(at: CGPoint(x: lane.minX + lane.width * 0.05, y: lane.midY))
            try await w.settle(untilStable: HaloWindowPlaybackTests.windowBodies)
            var routed = false
            let step = try await w.measure("halo select all keys, crowd (5,000 keys)", bodies: HaloWindowPlaybackTests.windowBodies) {
                try await w.ticks(1) { _ in
                    routed = w.window.firstResponder?.tryToPerform(#selector(NSResponder.selectAll(_:)), with: nil) ?? false
                }
            }
            #expect(routed, "selectAll: found no responder: the strip didn't take focus from the bed press")
            #if DEBUG
            #expect(HaloWindow.shownProject?.pickedKeyframes.count == 5_000, "⌘A didn't pick every key: \(step)")
            #endif
            return step
        }
    }
}
#endif
