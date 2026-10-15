// PhotoBrushLatencyTests.swift: how long one brush drag event takes to become
// a picture the canvas can draw, on a 4000 x 3000 image, done the way the
// window does it. PhotoWindow's `model.drag(...)` goes through SwiftUI's
// State, which has a get and a set but no in-place modify, so the drag
// mutates a copy while State keeps the old value (StateBox stands in for it;
// CanvasRenderer's in-flight render holds one the same way). CanvasRenderer
// then renders the tiles damaged since the revision it shows
// (PhotoRenderer.update) and makes their images (CanvasTiles.apply). The events are 120 steps of one
// steady stroke, each rendered before the next, the case where the renderer
// keeps up. The test prints p50 and p95 of each part as one BRUSH-LATENCY
// line and writes it to .build/snapshots/photo-brush-latency.txt, with a
// stroke's first event and its mouse-up, each the median of seven strokes.
// Not timed: SwiftUI's diff and draw, and Core Animation taking each new tile
// image. macOS only.
//
// Budgets, p50 per event. A 60 Hz frame is 16 ms; half of it is left for
// what this test can't time, so in a release build the timed parts get 8 ms.
// A debug build (CI's `swift test`) runs CoreRaster's per-pixel loops about
// 20x slower (an event's render takes ~4 ms release, ~55 ms debug, on an
// M-series Mac), which no total budget can separate from the copies, so there
// the total is only reported. The stroke's first event shares the drag's
// budget and its mouse-up gets a frame, in both builds. The drag has a budget
// in both builds, 3 ms:
// its own work is a few dabs (0.02 ms release, 0.6 ms debug), while copying
// the 240 MB a 4000 x 3000 layer and its stroke coverage hold takes over 6 ms
// even on a fast M-series Mac.
import CoreGraphics
import CoreRaster
import Foundation
import PhotoModel
import Testing

@testable import PhotoApp

@Suite struct PhotoBrushLatencyTests {
    #if DEBUG
    static let config = "debug"
    #else
    static let config = "release"
    #endif
    static let dragBudget = 3.0
    static let totalBudget: Double? = config == "release" ? 8 : nil

    @MainActor @Test func aBrushDragEventBecomesAFrameWithinBudget() async throws {
        let clock = ContinuousClock()
        var open = PhotoWorkspace()
        try open.newCanvas(width: 4000, height: 3000)
        open.selectTool(.brush)
        let state = StateBox(open)
        var started = clock.now
        let tiles = CanvasTiles()
        var shown = try await PhotoRenderer.update(state.value, since: nil).revision
        let firstFrame = milliseconds(clock.now - started)
        let path = (0...120).map { Mask.Point(x: 400 + 14 * Double($0), y: 1500 + 250 * sin(Double($0) / 12)) }

        var drag: [Double] = [], render: [Double] = [], image: [Double] = [], total: [Double] = []
        var strokeStarts: [Double] = []
        for (i, to) in path.enumerated() {
            let t0 = clock.now
            state.drag(from: i == 0 ? to : path[i - 1], to: to)
            let t1 = clock.now
            let next = try await PhotoRenderer.update(state.value, since: shown)
            let t2 = clock.now
            tiles.apply(next)
            let t3 = clock.now
            #expect(tiles.handedBytes == next.tiles.reduce(0) { $0 + $1.rgba8.count })
            shown = next.revision
            guard i > 0 else {
                strokeStarts.append(milliseconds(t1 - t0))
                continue
            }
            drag.append(milliseconds(t1 - t0))
            render.append(milliseconds(t2 - t1))
            image.append(milliseconds(t3 - t2))
            total.append(milliseconds(t3 - t0))
        }
        started = clock.now
        state.endDrag()
        var strokeEnds = [milliseconds(clock.now - started)]
        // A stroke has one first event and one mouse-up, so each is a single
        // sample, and a load spike on a shared runner can land on it (8.4 ms
        // once, against 1.0 ms on the run before). Six more short strokes
        // make both ends medians of seven; a whole-layer copy or walk would
        // still slow every one of them.
        for stroke in 1...6 {
            let y = 300 + 400 * Double(stroke)
            let t0 = clock.now
            state.drag(from: Mask.Point(x: 400, y: y), to: Mask.Point(x: 400, y: y))
            strokeStarts.append(milliseconds(clock.now - t0))
            state.drag(from: Mask.Point(x: 400, y: y), to: Mask.Point(x: 414, y: y))
            let t1 = clock.now
            state.endDrag()
            strokeEnds.append(milliseconds(clock.now - t1))
        }
        let strokeStart = percentile(strokeStarts, 0.5), strokeEnd = percentile(strokeEnds, 0.5)

        func split(_ name: String, _ values: [Double]) -> String {
            "\(name) p50 \(format(percentile(values, 0.5))) p95 \(format(percentile(values, 0.95)))"
        }
        let report = [
            "BRUSH-LATENCY config=\(Self.config) canvas=4000x3000 events=\(total.count) ms per event:",
            split("drag", drag) + ",", split("render", render) + ",", split("tiles", image) + ",",
            split("total", total), "| \(strokeStarts.count) strokes: first drag p50 \(format(strokeStart)),",
            "mouse-up p50 \(format(strokeEnd)),",
            "first frame \(format(firstFrame)) | budget p50 drag <= \(format(Self.dragBudget)),",
            "total <= \(Self.totalBudget.map(format) ?? "report only (debug)")",
        ].joined(separator: " ")
        print(report)
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data((report + "\n").utf8).write(to: folder.appending(path: "photo-brush-latency.txt"))

        #expect(percentile(drag, 0.5) <= Self.dragBudget, "\(report)")
        // The stroke's ends do no whole-layer work (PhotoBrushStrokeEndsTests).
        #expect(strokeStart <= Self.dragBudget && strokeEnd <= 16, "\(report)")
        if let budget = Self.totalBudget { #expect(percentile(total, 0.5) <= budget, "\(report)") }
    }

    /// PB-2 (packet photo-seams S-13): a clone or heal drag event to its
    /// picture on the `large` fixture, timed the way the brush's events are.
    /// Option at a press sets the source at (1200, 1500); the stroke presses
    /// 400 px to its right, untimed, then 60 events each move 20 px, more than
    /// a 64 px dab's 16 px spacing, so every timed event puts down a dab.
    /// Release p50 within 8 ms; debug reports it. Fewer than 60 samples fails.
    @MainActor @Test(arguments: [PhotoTool.clone, .heal])
    func aCloneOrHealDragEventBecomesAFrameWithinBudget(tool: PhotoTool) async throws {
        let name = tool == .heal ? "heal" : "clone"
        let clock = ContinuousClock()
        var open = try PhotoWorkspace.fixture(.large)
        open.selectTool(tool)
        open.setToolOption(.size(64))
        let state = StateBox(open)
        let source = Mask.Point(x: 1200, y: 1500)
        state.drag(from: source, to: source, modifiers: [.option])
        state.endDrag()
        #expect(state.value.cloneSource?.point == source)
        let tiles = CanvasTiles()
        var shown = try await PhotoRenderer.update(state.value, since: nil).revision
        let path = (0...60).map { Mask.Point(x: 1600 + 20 * Double($0), y: 1500) }

        var total: [Double] = []
        for (i, to) in path.enumerated() {
            let t0 = clock.now
            state.drag(from: i == 0 ? to : path[i - 1], to: to)
            let next = try await PhotoRenderer.update(state.value, since: shown)
            tiles.apply(next)
            let t1 = clock.now
            #expect(tiles.handedBytes == next.tiles.reduce(0) { $0 + $1.rgba8.count })
            shown = next.revision
            guard i > 0 else { continue }
            #expect(!next.tiles.isEmpty, "\(name) event \(i) put down no dab")
            total.append(milliseconds(t1 - t0))
        }
        state.endDrag()
        #expect(state.value.undoActionName == (tool == .heal ? "Undo Heal" : "Undo Clone"))

        let report = [
            "\(name.uppercased())-LATENCY config=\(Self.config) canvas=4000x3000 events=\(total.count) ms per event:",
            "total p50 \(format(percentile(total, 0.5))) p95 \(format(percentile(total, 0.95))) |",
            "budget p50 total <= \(Self.totalBudget.map(format) ?? "report only (debug)")",
        ].joined(separator: " ")
        print(report)
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data((report + "\n").utf8).write(to: folder.appending(path: "photo-\(name)-latency.txt"))

        #expect(total.count >= 60, "\(report)")
        if let budget = Self.totalBudget { #expect(percentile(total, 0.5) <= budget, "\(report)") }
    }
}

/// SwiftUI's State storage for the window's workspace: `model.drag(...)` in
/// PhotoWindow reads the value, mutates the copy and writes it back.
final class StateBox {
    private(set) var value: PhotoWorkspace

    init(_ value: PhotoWorkspace) { self.value = value }

    func drag(from a: Mask.Point, to b: Mask.Point, modifiers: DragModifiers = []) {
        var model = value
        model.drag(from: a, to: b, modifiers: modifiers)
        value = model
    }

    func endDrag() {
        var model = value
        model.endDrag()
        value = model
    }
}

func milliseconds(_ duration: Duration) -> Double { duration / .milliseconds(1) }

/// The nearest-rank percentile `p` (0...1) of `values`; 0 when empty.
func percentile(_ values: [Double], _ p: Double) -> Double {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return 0 }
    return sorted[min(Int((p * Double(sorted.count - 1)).rounded()), sorted.count - 1)]
}

func format(_ value: Double) -> String { String(format: "%.1f", value) }
