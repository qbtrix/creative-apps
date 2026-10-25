// IdleWorkTests.swift: what an app keeps doing after a gesture ends, the headless twin of the real-app perf
// gate's idle check (UITests/Journey+Health.swift: CPU 3 s after the gesture, two 1 s readings, the lower one
// under 10%). `IdleWork.watch` reads the process's CPU seconds and the debug counters once a second after the
// gesture, the way scripts/realperf-watch reads the app with `ps -o time=`, so a loop, a queued render or a
// recount that outlives the gesture shows as work in a second where nothing moves. Flare drags a marquee over
// the showcase document and counts its window bodies. Photo drags the Move tool 30 samples over a stress-shaped
// document (PhotoFixtures' `openStress` at a size a debug build composites in seconds: 60 layers, a quarter
// adjustment layers, a third masked) on the GPU and CPU routes, after one step that makes the cached base under
// the moved layer (the first step after any other change pays one full composite, as the open did), and counts
// the editor's bodies, the renderer's pictures and PhotoRenderCount's regions, layer composites, bases and hits.
// The gates are counts, never clocks, so a loaded Mac passes or fails the same way: every step waits for the
// work before it to drain (a deadline poll, not a sleep); the drag's renders drain, each region came from a kept
// base and laid one layer on it, a picture landed, and once drained nothing renders again. The CPU percent and
// the histogram's rows are printed, never gated (load moves the one, and the recount and the autosave 5 s after
// the last edit run on their own). Nested in BodyCountSuites, as every suite that reads a process-wide counter
// is. macOS only.
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

    /// Every counter's change over `readings`, summed.
    static func total(_ readings: some Sequence<IdleSecond>) -> [String: Int] {
        readings.reduce(into: [:]) { sum, reading in
            for (name, count) in reading.counts { sum[name, default: 0] += count }
        }
    }
}

extension BodyCountSuites {
    @MainActor @Suite(.serialized) struct IdleWorkTests {
        /// Polls `counts` every 100 ms, turning the run loop, until it has not changed for `quiet` polls or
        /// `limit` ms have passed; true when it went quiet. A deadline, not a sleep: on a loaded Mac the next step
        /// waits for the work in flight instead of starting on top of it.
        static func drained(_ w: RenderBudgetWindow<some View>, _ counts: () -> [String: Int], quiet: Int = 20,
                            limit: Int = 180_000) async throws -> Bool {
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
            return stable >= quiet
        }

        /// Polls every 100 ms until `condition` holds or `limit` ms have passed; true when it held.
        static func until(_ w: RenderBudgetWindow<some View>, limit: Int = 180_000, _ condition: () -> Bool) async throws -> Bool {
            var waited = 0
            while waited < limit, !condition() {
                w.host.layoutSubtreeIfNeeded()
                w.window.displayIfNeeded()
                try await Task.sleep(for: .milliseconds(100))
                waited += 100
            }
            return condition()
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
            #expect(try await Self.drained(w, Self.flareCounts), "the open never went quiet")
            let canvas = try #require(await w.element("suite.canvas")).insetBy(dx: 12, dy: 12)

            let before = Self.flareCounts()
            try await w.drag(from: CGPoint(x: canvas.minX, y: canvas.minY),
                             by: CGVector(dx: canvas.width, dy: canvas.height), samples: 60)
            #expect(try await Self.drained(w, Self.flareCounts), "the drag's work never went quiet")
            let drag = IdleWork.delta(Self.flareCounts(), since: before)
            let idle = try await IdleWork.watch(seconds: 3, counters: Self.flareCounts)

            let label = "IDLE-WORK flare marquee showcase \(PhotoRenderBudgetTests.config)"
            print("\(label): 60 drag samples and what they left" + IdleWork.describe(drag))
            for reading in idle { print("\(label): \(reading)") }
            // The drag runs the window a handful of times (start, end, commit), and once it is quiet it stays quiet.
            #expect(drag["bodies"] ?? 0 <= 3, Comment(rawValue: "\(label): the window ran per sample" + IdleWork.describe(drag)))
            #expect(IdleWork.total(idle)["bodies"] == 0, Comment(rawValue: "\(label): the window kept running after the drag"))
        }

        static func photoCounts() -> [String: Int] {
            #if DEBUG
            [
                "bodies": PhotoEditor.bodyRuns, "pictures": CanvasRenderer.pictures,
                "regions": PhotoRenderCount.regions.withLock { $0 }, "layers": PhotoRenderCount.layerComposites.withLock { $0 },
                "bases": PhotoRenderCount.bases.withLock { $0 }, "hits": PhotoRenderCount.hits.withLock { $0 },
                "rows": PhotoRenderCount.rows.withLock { $0 }, "rowLayers": PhotoRenderCount.rowLayers.withLock { $0 },
            ]
            #else
            [:]
            #endif
        }

        /// Polls, with a deadline, until no render is in flight on any renderer: a positive signal, so a loaded
        /// Mac that stalls one layer composite for seconds is waited for, never mistaken for quiet.
        static func rendered(_ w: RenderBudgetWindow<some View>) async throws -> Bool {
            #if DEBUG
            try await until(w) { CanvasRenderer.inFlight == 0 }
            #else
            true
            #endif
        }

        @Test(.disabled("red on dev: a Move step composites the whole stack and its renders outlive the drag; the fix PR enables it"),
              .timeLimit(.minutes(15)), arguments: [RenderingChoice.gpu, .cpu])
        func photoMoveSettlesAfterTheDrag(_ choice: RenderingChoice) async throws {
            var model = PhotoWorkspace(services: PhotoRenderBudgetTests.services)
            try model.openStress(width: 1024, height: 576, layers: 60)
            model.selectTool(.move)
            let rendering = PhotoRendering(preference: FakeRenderingPreference(choice: choice))
            let opened = Self.photoCounts()
            let w = RenderBudgetWindow(PhotoWindow(model: model).environment(\.photoRendering, rendering))
            let label = "IDLE-WORK photo move \(choice) 1024x576 60 layers \(PhotoRenderBudgetTests.config)"
            // The open's picture lands and its renders drain, on deadlines, so a loaded Mac waits rather than
            // starting a step on top of the open's render.
            #expect(try await Self.until(w) { (Self.photoCounts()["pictures"] ?? 0) > (opened["pictures"] ?? 0) },
                    Comment(rawValue: "\(label): the open's picture never landed"))
            #expect(try await Self.rendered(w), Comment(rawValue: "\(label): the open's renders never drained"))
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)

            // A step after an unchanged picture makes the base under the moved layer once per region (one full
            // composite, as the open's render was), and the first render into a new presenter texture is a full
            // one too. Steps go first until one is all hits, so the drag measures what every step after costs.
            var step: [String: Int] = [:], steps = 0
            repeat {
                let before = Self.photoCounts()
                try await w.ticks(1) { _ in send(.drag(CGPoint(x: 400, y: 300), CGPoint(x: 402 + Double(steps) * 2, y: 300))) }
                send(.endDrag)
                #expect(try await Self.rendered(w), Comment(rawValue: "\(label): step \(steps + 1)'s renders never drained"))
                step = IdleWork.delta(Self.photoCounts(), since: before)
                steps += 1
                print("\(label): step \(steps) and its renders" + IdleWork.describe(step))
            } while (step["bases"] ?? 0) > 0 && steps < 4
            #expect(step["bases"] == 0, Comment(rawValue: "\(label): \(steps) steps and each still made a base" + IdleWork.describe(step)))

            let before = Self.photoCounts()
            try await w.ticks(30) { i in
                send(.drag(CGPoint(x: 410, y: 300), CGPoint(x: 410 + Double(i) * 4, y: 300 + Double(i))))
            }
            send(.endDrag)
            let rendered = try await Self.rendered(w)
            let drag = IdleWork.delta(Self.photoCounts(), since: before)
            let idle = try await IdleWork.watch(seconds: 3, counters: Self.photoCounts)
            print("\(label): 30 drag samples and the renders they queued" + IdleWork.describe(drag))
            for reading in idle { print("\(label): \(reading)") }

            // Counts, not clocks. The drag's renders drain; every region came from a kept base (a hit, no base
            // made) and laid one layer on it, the moved one; at least one picture landed.
            #expect(rendered, Comment(rawValue: "\(label): the drag's renders never drained"))
            #expect(drag["bases"] == 0 && drag["hits"] == drag["regions"] && drag["layers"] == drag["regions"] && (drag["pictures"] ?? 0) >= 1,
                    Comment(rawValue: "\(label): a step did more than lay the moved layer on each region's kept base" + IdleWork.describe(drag)))
            // Once drained, the canvas stays still: no region starts, no picture lands.
            let after = IdleWork.total(idle)
            #expect(after["regions"] == 0 && after["pictures"] == 0,
                    Comment(rawValue: "\(label): the canvas rendered again after the drag's renders drained" + IdleWork.describe(after)))
            // The renderer outlives its window: let it finish before the next case counts.
            _ = try await Self.rendered(w)
            w.close()
        }
    }
}
#endif
