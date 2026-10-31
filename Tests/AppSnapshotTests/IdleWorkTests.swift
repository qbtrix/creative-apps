// IdleWorkTests.swift: what an app keeps doing after a gesture ends, the headless twin of the real-app perf
// gate's idle check (UITests/Journey+Health.swift: CPU 3 s after the gesture, two 1 s readings, the lower one
// under 10%). `IdleWork.watch` reads the process's CPU seconds and the debug counters once a second after the
// gesture, the way scripts/realperf-watch reads the app with `ps -o time=`, so a loop, a queued render or a
// recount that outlives the gesture shows as work in a second where nothing moves. Flare drags a marquee over
// the showcase document and counts its window bodies. Photo opens a stress-shaped document (PhotoFixtures'
// `openStress` at a size a debug build composites in seconds: 60 layers, a quarter adjustment layers, a third
// masked) on the GPU and CPU routes and drives the stress and real-perf journeys' gestures: the Move tool for 30
// samples (after steps that make the cached base under the moved layer), the Levels Black and Hue sliders for 30
// steps, and the top eyes toggled hidden then shown. It counts the editor's bodies, the renderer's pictures and
// PhotoRenderCount's regions, layer composites, bases and hits (the canvas) and rows and row layers (the Curves
// histogram's recount). The gates are counts, never clocks, so a loaded Mac passes or fails the same way: every
// step waits for the work before it to finish (a deadline poll, not a sleep); a Move drag is a compositor lift
// (docs/render-contract.md): its press renders the picture under the moved layer once, its samples render nothing,
// and its release lands one picture, so a 30-sample drag costs what a one-sample drag does; a Levels recount lays
// no layer, a Hue drag recounts nothing, and once a gesture's work has
// finished nothing renders or recounts again. A Free Transform step on a layer mid-stack, rendered straight
// through the renderer (no window) on the CPU and Metal routes, lays that layer and the ones above it on each
// region's kept base and makes no base, counted on a task-local tally so the suites running alongside never
// count into it. The CPU percent is printed, never gated (load moves it). The slider and eye tests drop the
// window's autosave after the gesture: on this branch it still flattens the picture through the reference path,
// which would read as a recount. Nested in BodyCountSuites, as every suite that reads a process-wide counter
// is. macOS only.
#if canImport(AppKit)
import AppKit
import CoreRaster
import FlareModel
import SuiteKernel
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

        static func label(_ gesture: String, _ choice: RenderingChoice) -> String {
            "IDLE-WORK photo \(gesture) \(choice) 1024x576 60 layers \(PhotoRenderBudgetTests.config)"
        }

        /// The counters a gesture's work moves: the canvas's renders and the histogram's recount. Not the editor's
        /// bodies, which a window's once-a-second tick runs on its own, so a wait on them would never go quiet.
        static func workCounts() -> [String: Int] {
            photoCounts().filter { ["regions", "layers", "pictures", "rows", "rowLayers"].contains($0.key) }
        }

        /// The stress document (1024 x 576 in 60 layers) open in a window on `choice`'s route with the Move tool
        /// picked, once the open's work has finished, on deadlines, so a loaded Mac waits rather than starting a
        /// gesture on top of it: its picture landed, its renders drained, and the histogram's first count (which
        /// keeps every row) went quiet. With the hook that sends intents, the window's edited view and the model.
        static func stressWindow(_ choice: RenderingChoice, _ label: String) async throws
            -> (window: RenderBudgetWindow<AnyView>, send: PhotoPerform, edited: PhotoWindowEditedView, model: PhotoWorkspace)
        {
            var model = PhotoWorkspace(services: PhotoRenderBudgetTests.services)
            try model.openStress(width: 1024, height: 576, layers: 60)
            model.selectTool(.select)
            let rendering = PhotoRendering(preference: FakeRenderingPreference(choice: choice))
            let opened = photoCounts()
            let w = RenderBudgetWindow(AnyView(PhotoWindow(model: model).environment(\.photoRendering, rendering)))
            #expect(try await until(w) { (photoCounts()["pictures"] ?? 0) > (opened["pictures"] ?? 0) },
                    Comment(rawValue: "\(label): the open's picture never landed"))
            #expect(try await rendered(w), Comment(rawValue: "\(label): the open's renders never drained"))
            #expect(try await drained(w, workCounts), Comment(rawValue: "\(label): the open's histogram count never went quiet"))
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            return (w, try #require(edited.send), edited, model)
        }

        /// Opens the stress window, runs `gesture` on it, and waits on deadlines for its work to finish: the
        /// canvas's renders drain, then the work counters hold still (the histogram's recount has no in-flight
        /// signal of its own). `check` gets every counter's change over the gesture and its work. Once finished,
        /// 3 s of readings may show no region, picture, histogram row or row layer. The window's autosave is
        /// dropped after the gesture (and again once the renders drain, for an edit noted late): it writes 5 s
        /// after the last edit and flattens the picture through the reference path, which counts rows.
        static func expectSettled(
            _ choice: RenderingChoice, _ name: String, _ failure: String, check: ([String: Int]) -> Bool,
            gesture: (RenderBudgetWindow<AnyView>, PhotoPerform, PhotoWorkspace) async throws -> Void
        ) async throws {
            let label = Self.label(name, choice)
            let (w, send, edited, model) = try await stressWindow(choice, label)
            let before = photoCounts()
            try await gesture(w, send, model)
            w.host.layoutSubtreeIfNeeded()
            w.window.displayIfNeeded()
            edited.files?.autosave?.discard()
            let rendered = try await Self.rendered(w)
            edited.files?.autosave?.discard()
            let drained = try await Self.drained(w, Self.workCounts)
            let work = IdleWork.delta(photoCounts(), since: before)
            let idle = try await IdleWork.watch(seconds: 3, counters: photoCounts)
            print("\(label): the gesture and its work" + IdleWork.describe(work))
            for reading in idle { print("\(label): \(reading)") }

            #expect(rendered, Comment(rawValue: "\(label): the gesture's renders never drained"))
            #expect(drained, Comment(rawValue: "\(label): the gesture's work never went quiet"))
            #expect(check(work), Comment(rawValue: "\(label): \(failure)" + IdleWork.describe(work)))
            let after = IdleWork.total(idle)
            #expect(["regions", "pictures", "rows", "rowLayers"].allSatisfy { after[$0] == 0 },
                    Comment(rawValue: "\(label): work ran again after the gesture's had finished" + IdleWork.describe(after)))
            // The renderer outlives its window: let it finish before the next case counts.
            _ = try await Self.rendered(w)
            w.close()
        }

        /// A bar slider's drag: 30 steps of `edit` at 120 Hz, then the gesture's end (one undo step).
        static func slide(_ w: RenderBudgetWindow<AnyView>, _ send: PhotoPerform, _ edit: (Int) -> AdjustmentEdit) async throws {
            try await w.ticks(30) { i in send(.adjust(edit(i))) }
            send(.endAdjust)
        }

        @Test(.timeLimit(.minutes(15)), arguments: [RenderingChoice.gpu, .cpu])
        func photoMoveSettlesAfterTheDrag(_ choice: RenderingChoice) async throws {
            let label = Self.label("move", choice)
            let (w, send, _, _) = try await Self.stressWindow(choice, label)

            // A Select drag pressed on the picked top layer (Layer 59's paint, x < 256 at y 300; Move folded into
            // Select) lifts the layer onto the compositor's live layer (PhotoTransformLift): the press renders
            // the picture under it once (one base per region, the layers below), each sample only places the lifted
            // pixels, and the release lands one picture where the layer was and is. So the drag's cost is per
            // drag, not per sample: a one-sample drag is the reference, measured after two steps that warm the
            // route (the first render into a new presenter texture is a full one, and the histogram's first
            // recounts).
            var step: [String: Int] = [:]
            for n in 1...3 {
                let before = Self.photoCounts()
                try await w.ticks(1) { _ in send(.drag(CGPoint(x: 128, y: 300), CGPoint(x: 128 + Double(n) * 2, y: 300))) }
                send(.endDrag)
                #expect(try await Self.rendered(w), Comment(rawValue: "\(label): step \(n)'s renders never drained"))
                step = IdleWork.delta(Self.photoCounts(), since: before)
                print("\(label): step \(n) and its renders" + IdleWork.describe(step))
            }
            #expect((step["pictures"] ?? 0) >= 1 && (step["bases"] ?? 0) <= (step["regions"] ?? 0),
                    Comment(rawValue: "\(label): a one-sample drag landed no picture, or made more than a base per region" + IdleWork.describe(step)))

            let before = Self.photoCounts()
            try await w.ticks(30) { i in
                send(.drag(CGPoint(x: 138, y: 300), CGPoint(x: 138 + Double(i) * 4, y: 300 + Double(i))))
            }
            send(.endDrag)
            let rendered = try await Self.rendered(w)
            let drag = IdleWork.delta(Self.photoCounts(), since: before)
            let idle = try await IdleWork.watch(seconds: 3, counters: Self.photoCounts)
            print("\(label): 30 drag samples and the renders they queued" + IdleWork.describe(drag))
            for reading in idle { print("\(label): \(reading)") }

            // Counts, not clocks. The drag's renders drain; 30 samples cost no more than one did on every canvas
            // counter (the lift's base at the press, nothing per sample, one picture at the release), and that
            // picture landed.
            #expect(rendered, Comment(rawValue: "\(label): the drag's renders never drained"))
            let perDrag = ["bases", "regions", "layers", "pictures"].allSatisfy { (drag[$0] ?? 0) <= (step[$0] ?? 0) }
            #expect(perDrag && (drag["pictures"] ?? 0) >= 1,
                    Comment(rawValue: "\(label): 30 samples rendered more than one sample does" + IdleWork.describe(drag) + "; one sample" + IdleWork.describe(step)))
            // Once drained, the canvas stays still: no region starts, no picture lands.
            let after = IdleWork.total(idle)
            #expect(after["regions"] == 0 && after["pictures"] == 0,
                    Comment(rawValue: "\(label): the canvas rendered again after the drag's renders drained" + IdleWork.describe(after)))
            // The renderer outlives its window: let it finish before the next case counts.
            _ = try await Self.rendered(w)
            w.close()
        }

        /// The Levels Black slider (the stress journey's `levels`): each step changes the histogram's key, so it
        /// recounts after the release, and that recount finds every row kept: it lays no layer.
        @Test(.timeLimit(.minutes(15)), arguments: [RenderingChoice.gpu, .cpu])
        func photoLevelsDragSettles(_ choice: RenderingChoice) async throws {
            try await Self.expectSettled(
                choice, "levels", "the histogram's recount after a tone edit composited layers, or never ran",
                check: { ($0["rows"] ?? 0) > 0 && $0["rowLayers"] == 0 }
            ) { w, send, _ in try await Self.slide(w, send) { .blackPoint(Float($0) / 200) } }
        }

        /// The Hue slider (the real-perf journey's `hue-sat`): outside the histogram's key, so nothing recounts.
        @Test(.timeLimit(.minutes(15)), arguments: [RenderingChoice.gpu, .cpu])
        func photoHueSatDragSettles(_ choice: RenderingChoice) async throws {
            try await Self.expectSettled(
                choice, "hue-sat", "the histogram recounted after an edit outside its key", check: { $0["rows"] == 0 }
            ) { w, send, _ in try await Self.slide(w, send) { .hue(Double($0) * 2) } }
        }

        /// The stress journey's `toggle-visibility`: the top eyes clicked twice each, hidden then shown, about
        /// 300 ms apart. Each click changes the stack, so the histogram recounts; once the last count and render
        /// finish, nothing runs again.
        @Test(.timeLimit(.minutes(15)), arguments: [RenderingChoice.gpu, .cpu])
        func photoToggleVisibilitySettles(_ choice: RenderingChoice) async throws {
            try await Self.expectSettled(
                choice, "toggle-visibility", "the histogram never recounted after the eyes changed the stack",
                check: { ($0["rows"] ?? 0) > 0 }
            ) { _, send, model in
                for id in model.layers.prefix(4).map(\.id) {
                    for _ in 0..<2 {
                        send(.toggleVisibility(id))
                        try await Task.sleep(for: .milliseconds(300))
                    }
                }
            }
        }

        /// A Free Transform step on a layer in the middle of the stack, rendered straight through the renderer
        /// on the CPU route and the Metal route (no window, so no histogram rows): after the first step, which
        /// makes the base under the layer, each step lays the transformed layer and the four above it on each
        /// region's kept base, and makes no base.
        @Test(.timeLimit(.minutes(5)), arguments: [false, true])
        func photoFreeTransformStepLaysTheLayerAndTheOnesAbove(gpu: Bool) async throws {
            guard !gpu || PhotoRenderBackendTests.device != nil else { return }
            let route = gpu ? PhotoRenderRoute(preferred: try PhotoRenderBackendTests.metal()) : PhotoRenderRoute()
            // A 600 x 400 white image under eight translucent full-canvas layers; Free Transform on the fifth from the top.
            var model = PhotoWorkspace(services: .live)
            try model.newCanvas(width: 600, height: 400)
            for n in 0..<8 {
                let color = RGBA(r: Float(n % 3) * 0.1, g: Float(n % 2) * 0.15, b: 0.2, a: 0.3)
                _ = model.insertLayer(named: "Wash \(n)", pixels: TiledPixels(try PixelBuffer(width: 600, height: 400, fill: color)),
                                      kind: .pixels, at: 0)
            }
            let above = 4
            model.selectLayer(model.layers[above].id)
            model.selectTool(.select)
            try model.beginTransform()
            let canvas = try #require(model.canvas)
            let tiles = PhotoRenderer.tiles(of: canvas, in: .all)
            let regions = gpu ? Set(tiles.map(\.y)).count : tiles.count
            let label = "IDLE-WORK photo free transform \(gpu ? "gpu" : "cpu") 600x400 9 layers"

            var shown = try await PhotoRenderer.update(model, since: nil, route: route)
            func turn() throws {
                let box = try #require(model.transformSelection)
                try model.setTransform(TransformRules.rotated(box, by: 3), name: "Rotate", drag: nil)
            }
            // This test's renders only (a task-local tally): suites running alongside draw too, and the
            // process-wide counters would count their work as this step's.
            func counted(_ render: () async throws -> PhotoTileUpdate) async throws -> [String: Int] {
                #if DEBUG
                let tally = PhotoRenderCount.Tally()
                shown = try await PhotoRenderCount.$tally.withValue(tally) { try await render() }
                return tally.snapshot
                #else
                shown = try await render()
                return [:]
                #endif
            }
            try turn()
            let first = try await counted { try await PhotoRenderer.update(model, since: shown.revision, route: route) }
            print("\(label): first step" + IdleWork.describe(first))

            for step in 1...4 {
                if step.isMultiple(of: 2) {
                    model.drag(from: Mask.Point(x: 300, y: 200), to: Mask.Point(x: 300 + Double(step) * 5, y: 200))
                    model.endDrag()
                } else {
                    try turn()
                }
                let step = try await counted { try await PhotoRenderer.update(model, since: shown.revision, route: route) }
                print("\(label): step" + IdleWork.describe(step))
                #if DEBUG
                #expect(step["bases", default: 0] == 0, Comment(rawValue: "\(label): a step made a base again" + IdleWork.describe(step)))
                #expect(step["hits"] == regions, Comment(rawValue: "\(label): a region missed its base" + IdleWork.describe(step)))
                #expect(step["layers"] == regions * (above + 1),
                        Comment(rawValue: "\(label): a step laid other than the layer and the \(above) above it per region"
                            + IdleWork.describe(step)))
                #endif
            }
            route.composites.removeAll()
        }
    }
}
#endif
