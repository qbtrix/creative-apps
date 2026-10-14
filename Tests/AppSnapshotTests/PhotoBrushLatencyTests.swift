// PhotoBrushLatencyTests.swift: how long one brush drag event takes to become
// a picture the canvas can draw, on a 4000 x 3000 image, done the way the
// window does it. PhotoWindow's `model.drag(...)` goes through SwiftUI's
// State, which has a get and a set but no in-place modify, so the drag
// mutates a copy while State keeps the old value (StateBox stands in for it;
// CanvasRenderer's in-flight render holds one the same way). CanvasRenderer
// then renders after the frame it keeps (PhotoRenderer.render) and wraps the
// bytes in a CGImage (CanvasRenderer.image). The events are 120 steps of one
// steady stroke, each rendered before the next, the case where the renderer
// keeps up. The test prints p50 and p95 of each part as one BRUSH-LATENCY
// line and writes it to .build/snapshots/photo-brush-latency.txt, with the
// stroke's first event and its mouse-up. Not timed: SwiftUI's diff and draw,
// and Core Animation taking each new full-size CGImage. macOS only.
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

    @Test func aBrushDragEventBecomesAFrameWithinBudget() async throws {
        let clock = ContinuousClock()
        var open = PhotoWorkspace()
        try open.newCanvas(width: 4000, height: 3000)
        open.selectTool(.brush)
        let state = StateBox(open)
        var started = clock.now
        var frame = try await PhotoRenderer.render(state.value)
        let firstFrame = milliseconds(clock.now - started)
        let path = (0...120).map { Mask.Point(x: 400 + 14 * Double($0), y: 1500 + 250 * sin(Double($0) / 12)) }

        var drag: [Double] = [], render: [Double] = [], image: [Double] = [], total: [Double] = []
        var strokeStart = 0.0
        for (i, to) in path.enumerated() {
            let t0 = clock.now
            state.drag(from: i == 0 ? to : path[i - 1], to: to)
            let t1 = clock.now
            let next = try await PhotoRenderer.render(state.value, after: frame)
            let t2 = clock.now
            let picture = CanvasRenderer.image(next)
            let t3 = clock.now
            #expect(picture != nil)
            frame = next
            guard i > 0 else {
                strokeStart = milliseconds(t1 - t0)
                continue
            }
            drag.append(milliseconds(t1 - t0))
            render.append(milliseconds(t2 - t1))
            image.append(milliseconds(t3 - t2))
            total.append(milliseconds(t3 - t0))
        }
        started = clock.now
        state.endDrag()
        let strokeEnd = milliseconds(clock.now - started)

        func split(_ name: String, _ values: [Double]) -> String {
            "\(name) p50 \(format(percentile(values, 0.5))) p95 \(format(percentile(values, 0.95)))"
        }
        let report = [
            "BRUSH-LATENCY config=\(Self.config) canvas=4000x3000 events=\(total.count) ms per event:",
            split("drag", drag) + ",", split("render", render) + ",", split("cgimage", image) + ",",
            split("total", total), "| stroke first drag \(format(strokeStart)), mouse-up \(format(strokeEnd)),",
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
}

/// SwiftUI's State storage for the window's workspace: `model.drag(...)` in
/// PhotoWindow reads the value, mutates the copy and writes it back.
final class StateBox {
    private(set) var value: PhotoWorkspace

    init(_ value: PhotoWorkspace) { self.value = value }

    func drag(from a: Mask.Point, to b: Mask.Point) {
        var model = value
        model.drag(from: a, to: b)
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
