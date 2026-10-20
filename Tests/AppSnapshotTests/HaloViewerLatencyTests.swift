// HaloViewerLatencyTests.swift: how long one viewer drag event takes to
// become a frame the viewer can draw, done the way HaloWindow does it, as
// PhotoBrushLatencyTests does for the brush (packet
// docs/blueprints/halo/features/core-loop.md, CL-11). The `keyed` sample on
// live services; the press lands on Floor, which the drag hits and selects.
// Each event is HaloViewerGestures' live path: a copy of the project takes
// `moveViewerDrag`, then its `viewerDrawList` is built, the list the canvas
// draws. Prints p50 and p95 of the move, the draw list and both together as
// one HALO-LATENCY line and writes it to .build/snapshots/halo-latency.txt.
// Report-only: no budget fails it. SwiftUI's own drawing isn't timed.
// macOS only.
#if canImport(AppKit)
import Foundation
import HaloModel
import Testing

@testable import HaloApp

@Suite struct HaloViewerLatencyTests {
    /// The line's prefix and the file it goes to, under the package root.
    static let prefix = "HALO-LATENCY"
    static let output = ".build/snapshots/halo-latency.txt"
    /// The drag's events: one steady 120-step drag, each event drawn before the next.
    static let steps = 120
    /// Where the press lands, in composition pixels: on Floor in `keyed`.
    static let press = HaloPoint(x: 960, y: 980)

    #if DEBUG
    static let config = "debug"
    #else
    static let config = "release"
    #endif

    /// One viewer drag event to a drawable frame, p50 and p95; writes the HALO-LATENCY line.
    @Test(.timeLimit(.minutes(2))) func viewerDragLatency() throws {
        var model = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
        try #require(model.selectedComposition != nil, "the keyed sample didn't open")
        model.beginViewerDrag(at: Self.press)
        try #require(model.viewerDrag != nil, "the press at \(Self.press) hit no layer")

        let clock = ContinuousClock()
        var move: [Double] = [], draw: [Double] = [], total: [Double] = []
        var last = Self.press
        for step in 1...Self.steps {
            let now = HaloPoint(x: Self.press.x + 2 * Double(step), y: Self.press.y + 0.5 * Double(step))
            last = now
            let t0 = clock.now
            var shown = model
            if shown.viewerDrag == nil { shown.beginViewerDrag(at: Self.press) }
            shown.moveViewerDrag(to: now)
            let t1 = clock.now
            let list = shown.viewerDrawList
            let t2 = clock.now
            #expect(list != nil, "event \(step) drew nothing")
            move.append(milliseconds(t1 - t0))
            draw.append(milliseconds(t2 - t1))
            total.append(milliseconds(t2 - t0))
        }
        // The release, as the window sends it: the last move, then the end.
        model.moveViewerDrag(to: last)
        model.endViewerDrag()

        func pair(_ values: [Double]) -> String {
            "p50 \(format(percentile(values, 0.5))) p95 \(format(percentile(values, 0.95)))"
        }
        let report = [
            "\(Self.prefix) config=\(Self.config) fixture=keyed events=\(total.count) ms per event:",
            "move \(pair(move)), draw list \(pair(draw)), total \(pair(total)) | report only",
        ].joined(separator: " ")
        print(report)
        let file = try packageRoot().appending(path: Self.output)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data((report + "\n").utf8).write(to: file)

        #expect(total.count == Self.steps, "\(report)")
        #expect(model.history.undoTitle == "Undo Move", "the drag recorded no Move: \(report)")
    }
}
#endif
