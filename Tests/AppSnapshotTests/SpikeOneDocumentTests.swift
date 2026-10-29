// SpikeOneDocumentTests.swift: SPIKE (spike/one-document, never merged). Measures, on the real Design
// window, (b) playback of the keyed 50- and 500-node fixtures through the SwiftUI painter vs one pre-rastered
// lift on SuiteUI's CanvasLiveLayer, (c) the painter's raster cost per node, and (d) the 2k crowd drag with the
// sampler in the loop vs without. Prints SPIKE lines; asserts nothing. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing
@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct SpikeOneDocumentTests {
        static func bodies() -> Int? {
            #if DEBUG
            return DesignWindow.bodyRuns
            #else
            return nil
            #endif
        }

        static func open(_ workspace: DesignWorkspace) async throws -> RenderBudgetWindow<DesignWindow> {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("spike-\(UUID()).design")
            try workspace.fileData().write(to: file)
            let w = RenderBudgetWindow(DesignWindow(launch: DesignLaunch(file: file)))
            try await w.settle(800)
            try await w.settle(untilStable: bodies)
            return w
        }

        static func report(_ name: String, _ times: [Double], bodies: Int?) {
            let s = times.sorted()
            let q = { (p: Double) in s.isEmpty ? 0 : s[min(s.count - 1, Int(Double(s.count) * p))] }
            print(String(format: "SPIKE %@: frames %d | p50 %.2f p95 %.2f max %.2f ms | over 8.3 ms %d | over 16.7 ms %d | window bodies %@",
                         name, s.count, q(0.5), q(0.95), s.last ?? 0, s.filter { $0 > 8.33 }.count, s.filter { $0 > 16.7 }.count,
                         bodies.map(String.init) ?? "n/a"))
        }

        /// One timed frame: `action`, then the layout and display it forced (RenderBudgetWindow.timed's method).
        static func timed(_ w: RenderBudgetWindow<DesignWindow>, _ action: () -> Void) -> Double {
            let clock = ContinuousClock(), began = clock.now
            action()
            w.host.layoutSubtreeIfNeeded()
            w.window.displayIfNeeded()
            return Double((clock.now - began) / .microseconds(1)) / 1000
        }

        static func host(in view: NSView) -> CanvasHostView? {
            if let host = view as? CanvasHostView { return host }
            for sub in view.subviews { if let found = host(in: sub) { return found } }
            return nil
        }

        /// (b) Two passes over frames 0...120 (one PlaybackTiming tick per document frame), painter vs lift.
        @Test(.timeLimit(.minutes(3))) func playback() async throws {
            let clock = DesignSpikeClock.shared
            defer { clock.stop() }
            for count in [50, 500] {
                let workspace = DesignFixtures.animated(count)
                let w = try await Self.open(workspace)
                defer { w.close() }
                clock.frame = 0
                try await w.settle(300)
                let before = Self.bodies()
                var times: [Double] = []
                for i in 0..<242 {
                    let tick = PlaybackTiming.tick(startFrame: 0, elapsed: Double(i % 121) / 60, rate: DesignNodeTime.rate,
                                                   durationFrames: 121, mode: .once)
                    times.append(Self.timed(w) { clock.frame = Double(tick.frame) })
                }
                Self.report("painter play \(count) nodes", times, bodies: Self.bodies().map { $0 - (before ?? 0) })

                // The lift: the whole frame pre-rastered once, then moved on the live layer each frame.
                let page = try #require(workspace.selectedPage)
                let rasterClock = ContinuousClock(), began = rasterClock.now
                let renderer = ImageRenderer(content: DesignArtwork(painted: page.sampled(at: 0).painted, zoom: 1)
                    .frame(width: page.frameWidth, height: page.frameHeight))
                renderer.scale = 2
                let image = try #require(renderer.cgImage)
                let rasterMs = Double((rasterClock.now - began) / .microseconds(1)) / 1000
                guard let canvas = Self.host(in: w.window.contentView!) else {
                    print("SPIKE lift \(count) nodes: no CanvasHostView in the Design window"); continue
                }
                let size = CGSize(width: image.width, height: image.height)
                canvas.showLiveLayer(CanvasLiveLayer(contents: image, size: size), at: .init(scaleX: 0.5, y: 0.5))
                let liftBefore = Self.bodies()
                var lift: [Double] = []
                for i in 0..<242 {
                    let dx = Double(i % 121) / 12
                    lift.append(Self.timed(w) { canvas.moveLiveLayer(CGAffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: dx, ty: 0)) })
                }
                canvas.dropLiveLayer()
                print(String(format: "SPIKE lift %d nodes: pre-raster %.1f ms (%.0f x %.0f px)", count, rasterMs, size.width, size.height))
                Self.report("lift play \(count) nodes", lift, bodies: Self.bodies().map { $0 - (liftBefore ?? 0) })
                clock.frame = nil
            }
        }

        /// (c) The painter's CPU raster at screen scale (2x): the sampled tree through DesignArtwork, off-window.
        @Test(.timeLimit(.minutes(3))) func rasterCost() async throws {
            for count in [50, 500] {
                let page = try #require(DesignFixtures.animated(count).selectedPage)
                var times: [Double] = []
                for f in stride(from: 0, through: 120, by: 4) {
                    let clock = ContinuousClock(), began = clock.now
                    let sampled = page.sampled(at: Double(f))
                    let sampleMs = Double((clock.now - began) / .microseconds(1)) / 1000
                    let renderer = ImageRenderer(content: DesignArtwork(painted: sampled.painted, zoom: 1)
                        .frame(width: page.frameWidth, height: page.frameHeight))
                    renderer.scale = 2
                    _ = renderer.cgImage
                    times.append(Double((clock.now - began) / .microseconds(1)) / 1000)
                    if f == 60 { print(String(format: "SPIKE sample-only %d nodes: %.3f ms", count, sampleMs)) }
                }
                let s = times.sorted()
                print(String(format: "SPIKE raster %d nodes at 2x: p50 %.2f p95 %.2f ms | p50 per node %.1f us", count,
                             s[s.count / 2], s[Int(Double(s.count) * 0.95)], s[s.count / 2] * 1000 / Double(count + 1)))
            }
        }

        /// (c) 20+ s of painter playback of the 500-node fixture for `sample <pid> 20 1`.
        @Test(.timeLimit(.minutes(3))) func playLongForSample() async throws {
            let w = try await Self.open(DesignFixtures.animated(500))
            defer { w.close() }
            let clock = DesignSpikeClock.shared
            defer { clock.stop() }
            print("SPIKE-SAMPLE-START pid \(ProcessInfo.processInfo.processIdentifier)")
            let start = Date()
            var frames = 0
            while Date().timeIntervalSince(start) < 24 {
                let tick = PlaybackTiming.tick(startFrame: 0, elapsed: Double(frames % 121) / 60, rate: DesignNodeTime.rate,
                                               durationFrames: 121, mode: .once)
                _ = Self.timed(w) { clock.frame = Double(tick.frame) }
                frames += 1
                if frames % 30 == 0 { try await Task.sleep(for: .milliseconds(1)) }
            }
            print(String(format: "SPIKE-SAMPLE-END frames %d in 24 s (%.1f fps unthrottled)", frames, Double(frames) / 24))
        }

        /// (d) The crowd drag (RenderBudgetDesignTests' 120-sample drag), plain vs keyed and sampled at 1 s.
        @Test(.timeLimit(.minutes(3))) func crowdDrag() async throws {
            for (name, workspace, playhead) in [("plain crowd", DesignFixtures.crowd, Double?.none),
                                                ("keyed crowd sampled at 1 s", DesignFixtures.keyedCrowd, 60)] {
                let w = try await Self.open(workspace)
                defer { w.close() }
                DesignSpikeClock.shared.frame = playhead
                defer { DesignSpikeClock.shared.frame = nil }
                try await w.settle(untilStable: Self.bodies)
                let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
                let page = CGSize(width: 1440, height: 1024)
                let step = try await w.measure("SPIKE drag \(name)", bodies: Self.bodies) {
                    try await w.drag(from: w.point(CGPoint(x: 20, y: 20), on: page, in: board), by: CGVector(dx: 160, dy: -90))
                }
                _ = step
            }
        }
    }
}
#endif
