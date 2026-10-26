// IdleWorkTests.swift: what an app keeps doing after a gesture ends, the headless twin of the real-app perf
// gate's idle check (UITests/Journey+Health.swift: CPU 3 s after the gesture, two 1 s readings, the lower one
// under 10%). `IdleWork.watch` reads the process's CPU seconds and the debug counters once a second after the
// gesture, the way scripts/realperf-watch reads the app with `ps -o time=`, so a loop, a queued render or a
// recount that outlives the gesture shows as work in a second where nothing moves. Flare drags a marquee over
// the showcase document and counts its window bodies. Photo drags the Move tool 30 samples over a stress-shaped
// document (PhotoFixtures' `openStress` at a size a debug build composites in seconds: 60 layers, a quarter
// adjustment layers, a third masked) on the GPU and CPU routes, after one step that makes the cached base under
// the moved layer (the first step after any other change pays one full composite, as the open did), and counts
// the editor's bodies, the renderer's pictures and PhotoRenderCount's regions and layer composites: a step may
// lay one layer per region and nothing may still be drawing in the gate's readings. Each reports every second;
// the CPU percent is printed, never gated (load moves it, and the autosave 5 s after the last edit encodes the
// document). Nested in BodyCountSuites, as every suite that reads a process-wide counter is. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp
@testable import PhotoApp
@testable import PhotoModel
@testable import SuiteUI

/// One second after a gesture: the CPU the process used over it as a percent of one core, and each counter's change.
struct IdleSecond: CustomStringConvertible {
    let second: Int
    let cpuPercent: Double
    let counts: [String: Int]

    var description: String {
        String(format: "+%d s: cpu %.0f%%", second, cpuPercent) + IdleWork.describe(counts)
    }

    /// Whether none of `names` moved over this second.
    func isStill(_ names: [String]) -> Bool { names.allSatisfy { counts[$0] == 0 } }
}

enum IdleWork {
    /// CPU seconds this process has used, every thread together.
    static func cpuSeconds() -> Double {
        var time = timespec()
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &time)
        return Double(time.tv_sec) + Double(time.tv_nsec) / 1e9
    }

    /// `seconds` one-second readings after a gesture that ended now; `counters` is read at the end of each
    /// second and reported as the change over it.
    @MainActor static func watch(seconds: Int, counters: () -> [String: Int]) async throws -> [IdleSecond] {
        var readings: [IdleSecond] = []
        let began = ContinuousClock.now
        var (cpu, counts, wall) = (cpuSeconds(), counters(), began)
        for second in 1...seconds {
            try await Task.sleep(until: began + .seconds(second), clock: .continuous)
            let (now, cpuNow, countsNow) = (ContinuousClock.now, cpuSeconds(), counters())
            let elapsed = Double((now - wall) / .microseconds(1)) / 1e6
            readings.append(IdleSecond(
                second: second, cpuPercent: (cpuNow - cpu) / max(elapsed, 1e-3) * 100,
                counts: countsNow.merging(counts) { now, before in now - before }))
            (cpu, counts, wall) = (cpuNow, countsNow, now)
        }
        return readings
    }

    static func describe(_ counts: [String: Int]) -> String {
        counts.keys.sorted().map { ", \($0) \(counts[$0] ?? 0)" }.joined()
    }

    /// `now` less `before`, per counter.
    static func delta(_ now: [String: Int], since before: [String: Int]) -> [String: Int] {
        now.merging(before) { now, before in now - before }
    }
}

extension BodyCountSuites {
    @MainActor @Suite(.serialized) struct IdleWorkTests {
        /// The gate's two readings start 3 s after the gesture; the lower one passes it.
        static let gate = 3...4

        /// Turns the run loop until `counts` has not changed for `quiet` checks 100 ms apart (an open's
        /// render, a drag's last render and the first layouts are done), or `limit` ms have passed.
        static func settle(_ w: RenderBudgetWindow<some View>, _ counts: () -> [String: Int], quiet: Int = 15, limit: Int = 120_000) async throws {
            var last = counts(), stable = 0, waited = 0
            while waited < limit, stable < quiet {
                w.host.layoutSubtreeIfNeeded()
                w.window.displayIfNeeded()
                try await Task.sleep(for: .milliseconds(100))
                waited += 100
                let now = counts()
                stable = now == last ? stable + 1 : 0
                last = now
            }
        }

        static func flareCounts() -> [String: Int] {
            #if DEBUG
            ["bodies": FlareWindow.bodyRuns]
            #else
            [:]
            #endif
        }

        @Test(.timeLimit(.minutes(5))) func flareMarqueeSettlesAfterTheDrag() async throws {
            var model = FlareWorkspace(services: .built)
            model.finishOpen(.success(try #require(FlareFixtures.named("showcase"))), named: "Showcase.flare")
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            try await Self.settle(w, Self.flareCounts)
            let canvas = try #require(await w.element("suite.canvas")).insetBy(dx: 12, dy: 12)

            let before = Self.flareCounts()
            try await w.drag(from: CGPoint(x: canvas.minX, y: canvas.minY),
                             by: CGVector(dx: canvas.width, dy: canvas.height), samples: 60)
            let during = IdleWork.delta(Self.flareCounts(), since: before)
            let idle = try await IdleWork.watch(seconds: 5, counters: Self.flareCounts)

            let label = "IDLE-WORK flare marquee showcase \(PhotoRenderBudgetTests.config)"
            print("\(label): 60 drag samples" + IdleWork.describe(during))
            for reading in idle { print("\(label): \(reading)") }
            #expect(idle[Self.gate].contains { $0.isStill(["bodies"]) },
                    Comment(rawValue: "\(label): the window kept running through the gate's readings"))
        }

        static func photoCounts() -> [String: Int] {
            #if DEBUG
            [
                "bodies": PhotoEditor.bodyRuns, "pictures": CanvasRenderer.pictures,
                "regions": PhotoRenderCount.regions.withLock { $0 },
                "layers": PhotoRenderCount.layerComposites.withLock { $0 },
            ]
            #else
            [:]
            #endif
        }

        @Test(.disabled("red on dev: a Move step composites the whole stack and its renders outlive the drag; the fix PR enables it"),
              .timeLimit(.minutes(10)), arguments: [RenderingChoice.gpu, .cpu])
        func photoMoveSettlesAfterTheDrag(_ choice: RenderingChoice) async throws {
            var model = PhotoWorkspace(services: PhotoRenderBudgetTests.services)
            try model.openStress(width: 1024, height: 576, layers: 60)
            model.selectTool(.move)
            let rendering = PhotoRendering(preference: FakeRenderingPreference(choice: choice))
            let w = RenderBudgetWindow(PhotoWindow(model: model).environment(\.photoRendering, rendering))
            let canvas = try #require(await w.first(CanvasHostView.self))
            for _ in 0..<600 where !PhotoZoomBudgetTests.shows(canvas) { try await Task.sleep(for: .milliseconds(50)) }
            try await Self.settle(w, Self.photoCounts)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)
            let label = "IDLE-WORK photo move \(choice) 1024x576 60 layers \(PhotoRenderBudgetTests.config)"

            // The first step after an unchanged picture makes the base under the moved layer once, per region
            // (one full composite, as the open's render was); a drag's cost is what every step after that costs.
            var before = Self.photoCounts()
            try await w.ticks(1) { _ in send(.drag(CGPoint(x: 400, y: 300), CGPoint(x: 402, y: 300))) }
            send(.endDrag)
            try await Self.settle(w, Self.photoCounts)
            print("\(label): first step and its renders" + IdleWork.describe(IdleWork.delta(Self.photoCounts(), since: before)))

            before = Self.photoCounts()
            try await w.ticks(30) { i in
                send(.drag(CGPoint(x: 402, y: 300), CGPoint(x: 402 + Double(i) * 4, y: 300 + Double(i))))
            }
            send(.endDrag)
            let during = IdleWork.delta(Self.photoCounts(), since: before)
            let idle = try await IdleWork.watch(seconds: 6, counters: Self.photoCounts)
            print("\(label): 30 drag samples" + IdleWork.describe(during))
            for reading in idle { print("\(label): \(reading)") }

            // A step moves the top layer: each region lays that one layer on its kept base, never the stack.
            #expect(during["layers"] ?? 0 <= during["regions"] ?? 0,
                    Comment(rawValue: "\(label): a step composited more than the moved layer per region" + IdleWork.describe(during)))
            // Nothing may still be drawing for the drag in the gate's readings: no region, no picture, no editor pass.
            #expect(idle[Self.gate].contains { $0.isStill(["regions", "pictures", "bodies"]) },
                    Comment(rawValue: "\(label): the drag's work ran through both of the gate's readings"))
            // The renderer outlives its window: let it finish before the next case counts.
            try await Self.settle(w, Self.photoCounts)
            w.close()
        }
    }
}
#endif
