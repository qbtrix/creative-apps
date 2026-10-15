// PhotoBrushInkLatencyTests.swift: the brush's native-feel spec. Native Mac
// drawing apps put ink under the pointer within about one display frame and
// keep a fast stroke smooth, so this drives the window's live drag path in
// real time and times it: pointer samples arrive at 120 Hz from a main run
// loop timer (a fast hand on a 120 Hz mouse or trackpad), go through
// StrokePacer to the workspace on State's copy (StateBox) and on to
// CanvasRenderer, which renders the damaged tiles and hands them to the tile
// layers (CanvasTiles, a TileCanvasView), exactly as PhotoWindow wires them.
// The stroke is 120 samples, 16 px apart, of a 64 px brush on a 4000 x 3000
// image (about 1,900 px a second).
//
// Per sample it measures input to ink: from the sample's arrival to the
// moment the tiles holding what it painted are committed to the layers (the
// renderer's `onPicture`). Core Animation shows a commit at the next display
// refresh for every app alike, so the commit is the part the app controls.
// Frame pacing: the longest gap between two pictures while the stroke runs.
//
// Budgets, release only (a debug build runs CoreRaster's per-pixel loops about
// 20x slower, so there the line is a report): input to ink p95 <= 16.7 ms,
// one 60 Hz frame; no gap between pictures over two frames (33.3 ms). Report:
// one BRUSH-INK line in .build/snapshots/photo-brush-ink.txt. macOS only.
import AppKit
import CoreRaster
import Foundation
import PhotoModel
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoBrushInkLatencyTests {
    static let config = PhotoBrushLatencyTests.config
    static let frame = 1000.0 / 60
    static let latencyBudget: Double? = config == "release" ? frame : nil
    static let hitchBudget: Double? = config == "release" ? 2 * frame : nil
    static let path = (0..<120).map { Mask.Point(x: 400 + 16 * Double($0), y: 1500 + 250 * sin(Double($0) / 12)) }

    /// What the stroke saw, sample by sample.
    @MainActor final class Recorder {
        let clock = ContinuousClock()
        var input: [ContinuousClock.Instant] = []
        /// The revision of the apply that took each sample.
        var applied: [Int?] = []
        var pending: [Int] = []
        var pictures: [(revision: Int, at: ContinuousClock.Instant)] = []
    }

    @Test(.timeLimit(.minutes(2))) func brushInkLandsWithinAFrameAtFullRate() async throws {
        var open = PhotoWorkspace()
        try open.newCanvas(width: 4000, height: 3000)
        open.selectTool(.brush)
        open.setToolOption(.size(64))
        let state = StateBox(open)
        let renderer = CanvasRenderer()
        renderer.tiles.attach(TileCanvasView(frame: CGRect(x: 0, y: 0, width: 1000, height: 750)))
        renderer.show(state.value)
        try await shown(state.value.revision, renderer)

        let record = Recorder()
        renderer.onPicture = { record.pictures.append(($0, record.clock.now)) }
        let pacer = StrokePacer()
        let apply: ([StrokePacer.Move]) -> Void = { moves in
            state.drags(moves)
            for i in record.pending { record.applied[i] = state.value.revision }
            record.pending = []
            renderer.show(state.value)
        }
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            var i = 0
            let timer = Timer(timeInterval: 1 / 120, repeats: true) { timer in
                MainActor.assumeIsolated {
                    guard i < Self.path.count else {
                        timer.invalidate()
                        return done.resume()
                    }
                    record.input.append(record.clock.now)
                    record.applied.append(nil)
                    record.pending.append(i)
                    let to = Self.path[i]
                    pacer.add((from: i == 0 ? to : Self.path[i - 1], to: to, pressure: 1, modifiers: []), apply: apply)
                    i += 1
                }
            }
            RunLoop.main.add(timer, forMode: .common)
        }
        pacer.stop()
        try await shown(state.value.revision, renderer)
        state.endDrag()

        // A sample's ink: the first picture at or after it that shows its revision.
        var latency: [Double] = []
        for (i, at) in record.input.enumerated().dropFirst() {
            guard let revision = record.applied[i],
                let ink = record.pictures.first(where: { $0.revision >= revision && $0.at >= at })
            else { continue }
            latency.append(milliseconds(ink.at - at))
        }
        let times = record.pictures.map(\.at)
        let gaps = zip(times.dropFirst(), times).map { milliseconds($0 - $1) }
        let longest = gaps.max() ?? 0
        let report = [
            "BRUSH-INK config=\(Self.config) canvas=4000x3000 brush=64px input=120Hz samples=\(latency.count)",
            "pictures=\(record.pictures.count) | input to ink p50 \(format(percentile(latency, 0.5)))",
            "p95 \(format(percentile(latency, 0.95))) max \(format(latency.max() ?? 0)) ms",
            "| picture gap p95 \(format(percentile(gaps, 0.95))) max \(format(longest)) ms,",
            "\(gaps.filter { $0 > 2 * Self.frame }.count) over 2 frames | render p50",
            "\(format(renderer.lastMilliseconds ?? 0)) ms | budget p95 <=",
            Self.latencyBudget.map { "\(format($0)) ms, gaps <= \(format(2 * Self.frame)) ms" }
                ?? "report only (debug)",
        ].joined(separator: " ")
        print(report)
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data((report + "\n").utf8).write(to: folder.appending(path: "photo-brush-ink.txt"))

        #expect(latency.count >= Self.path.count - 2, "\(report)")
        if let budget = Self.latencyBudget { #expect(percentile(latency, 0.95) <= budget, "\(report)") }
        if let budget = Self.hitchBudget { #expect(longest <= budget, "\(report)") }
    }

    /// Waits up to two seconds for the renderer to show `revision`.
    private func shown(_ revision: Int, _ renderer: CanvasRenderer) async throws {
        for _ in 0..<400 where renderer.revision != revision { try await Task.sleep(for: .milliseconds(5)) }
        #expect(renderer.revision == revision && renderer.failure == nil, "\(renderer.failure ?? "")")
    }
}
