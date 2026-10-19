// PhotoZoomBudgetTests.swift: what panning and an adjustment-slider drag cost
// the real Photo window on an 8K document (7680 x 4320, PhotoRenderBudgetTests'
// three layers) at 50, 100, 150, 200 and 300 % zoom, on each View > Rendering
// backend (the tile layers on the CPU, the Metal layer on the GPU). On the
// render budget harness: a pan is 60 steps of the canvas scroll view moved
// 8 pt (as a wheel or a Space-drag moves it), a slider drag 30 exposure
// changes sent as the slider sends them. Each step is timed as the harness
// times it (the event plus the layout and display it forced); `main stall` is
// how late the main thread was to its 120 Hz ticks during the
// interaction (longest single stall, and the total) as a main-queue
// heartbeat sees it: renders that land on the main thread show up there, not
// in the step. Report-only
// (Tests/perf-suites.txt): one PHOTO-ZOOM-8K line per backend, zoom and
// interaction in .build/snapshots/photo-zoom-budget.txt. macOS only.
import AppKit
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite(.serialized) struct PhotoZoomBudgetTests {
        static let zooms = [0.5, 1, 1.5, 2, 3]

        @Test(.timeLimit(.minutes(40))) func eightKPanAndSliderAtEachZoomOnEachBackend() async throws {
            var lines: [String] = []
            // PHOTO_ZOOM_ONLY=GPU or =CPU runs one backend, PHOTO_ZOOM_AT=1 one zoom: a run to `sample`.
            let env = ProcessInfo.processInfo.environment
            let backends = [("CPU", RenderingChoice.cpu), ("GPU", .gpu)].filter { backend in
                env["PHOTO_ZOOM_ONLY"].map { $0 == backend.0 } ?? true
            }
            let zooms = env["PHOTO_ZOOM_AT"].flatMap(Double.init).map { [$0] } ?? Self.zooms
            for (label, choice) in backends {
                for zoom in zooms {
                    lines += try await Self.measure(label, choice, zoom: zoom)
                }
            }
            let folder = URL(fileURLWithPath: ".build/snapshots", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n").write(
                to: folder.appendingPathComponent("photo-zoom-budget.txt"), atomically: true, encoding: .utf8)
        }

        /// One window at `zoom` on `choice`: a pan and a slider drag, measured.
        static func measure(_ label: String, _ choice: RenderingChoice, zoom: Double) async throws -> [String] {
            let rendering = PhotoRendering(preference: FakeRenderingPreference(choice: choice))
            let w = RenderBudgetWindow(
                PhotoWindow(model: try PhotoRenderBudgetTests.document(), zoom: zoom).environment(\.photoRendering, rendering))
            defer { w.close() }
            let canvas = try #require(await w.first(CanvasHostView.self))
            for _ in 0..<600 where !shows(canvas) { try await Task.sleep(for: .milliseconds(50)) }
            try await w.settle(1000)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)
            let box = canvas.convert(canvas.bounds, to: nil)
            let scroll = try #require(canvas.enclosingScrollView ?? w.scrollView(at: CGPoint(x: 640, y: 410)))

            let presents = { (canvas.presenter as? CanvasTilePresenter)?.presented ?? 0 }
            let presentsBefore = presents()
            var stall = (longest: 0.0, total: 0.0)
            let pan = try await w.measure("photo 8K pan \(label) \(Int(zoom * 100))%", bodies: { nil }) {
                stall = try await stalls(w, 60) { i in
                    let clip = scroll.contentView
                    clip.scroll(to: NSPoint(x: clip.bounds.origin.x + (i % 30 < 15 ? 8 : -8), y: clip.bounds.origin.y + 4))
                    scroll.reflectScrolledClipView(clip)
                    // The Core Animation commit the scroll forces, as the zoom sweep times it.
                    w.host.layoutSubtreeIfNeeded()
                    w.window.displayIfNeeded()
                    CATransaction.flush()
                }
            }
            var sliderStall = (longest: 0.0, total: 0.0)
            let slider = try await w.measure("photo 8K slider \(label) \(Int(zoom * 100))%", bodies: { nil }) {
                sliderStall = try await stalls(w, 30) { i in send(.adjust(.exposure(Float(i) / 60))) }
                send(.endAdjust)
            }
            let panLine = line("pan", label, zoom, pan, stall) + " | presents during the pan \(presents() - presentsBefore)"
            return [panLine, line("slider", label, zoom, slider, sliderStall)].map {
                print($0)
                return $0
            }
        }

        static func line(_ kind: String, _ label: String, _ zoom: Double, _ step: RenderStep,
                         _ stall: (longest: Double, total: Double)) -> String {
            String(format: "PHOTO-ZOOM-8K %@ %@ %3.0f%% %@: step p50 %.2f ms p95 %.2f ms | main stall longest %.1f ms, total %.0f ms",
                   kind, label, zoom * 100, PhotoRenderBudgetTests.config, step.p50, step.p95, stall.longest, stall.total)
        }

        /// `count` timed steps at 120 Hz, then 60 idle ticks for the renders they asked for to land, while a
        /// main-queue heartbeat (a Dispatch timer every 2 ms, outside Swift concurrency, so a busy cooperative
        /// pool can't delay it) records how long the main thread was busy past each beat. Returns the longest
        /// such stall and their total, in ms: what a slider or a pan feels when renders land on the main thread.
        static func stalls(_ w: RenderBudgetWindow<some View>, _ count: Int, _ step: (Int) -> Void) async throws
            -> (longest: Double, total: Double)
        {
            let beat = MainHeartbeat()
            defer { beat.stop() }
            let clock = ContinuousClock()
            let began = clock.now
            for i in 1...(count + 60) {
                try await Task.sleep(until: began + .microseconds(8_333 * i), clock: clock)
                if i <= count { w.timed { step(i) } }
            }
            return (beat.longest * 1000, beat.total * 1000)
        }

        /// The canvas shows a picture: its tile layers have images (on the GPU path too, under the Metal layer).
        static func shows(_ canvas: CanvasHostView) -> Bool {
            !(canvas.layer?.sublayers?.first?.sublayers ?? []).compactMap(\.contents).isEmpty
        }
    }
}

/// A main-queue Dispatch timer every 2 ms; each fire that comes more than a beat late adds the lateness.
@MainActor private final class MainHeartbeat {
    private let timer = DispatchSource.makeTimerSource(queue: .main)
    private var last = ProcessInfo.processInfo.systemUptime
    private(set) var longest = 0.0, total = 0.0
    private static let interval = 0.002

    init() {
        timer.schedule(deadline: .now(), repeating: .milliseconds(2), leeway: .microseconds(200))
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.fire() } }
        timer.resume()
    }

    private func fire() {
        let now = ProcessInfo.processInfo.systemUptime
        let late = max(now - last - Self.interval, 0)
        (longest, total, last) = (max(longest, late), total + late, now)
    }

    func stop() { timer.cancel() }
}
