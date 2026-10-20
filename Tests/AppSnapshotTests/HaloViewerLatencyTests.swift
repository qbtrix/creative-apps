// HaloViewerLatencyTests.swift: how long one viewer drag event takes to
// become a frame the viewer can draw, done the way HaloWindow does it, as
// PhotoBrushLatencyTests does for the brush (packet
// docs/blueprints/halo/features/core-loop.md, CL-11). It will print p50 and
// p95 as one HALO-LATENCY line and write it to
// .build/snapshots/halo-latency.txt, report-only. CL-3 adds the scaffold
// disabled; CL-11 writes the measurement and turns it on. macOS only.
#if canImport(AppKit)
import Testing

@Suite struct HaloViewerLatencyTests {
    /// The line's prefix and the file it goes to, under the package root.
    static let prefix = "HALO-LATENCY"
    static let output = ".build/snapshots/halo-latency.txt"
    /// The drag's events: one steady 120-step drag, each event drawn before the next.
    static let steps = 120

    /// One viewer drag event to a drawable frame, p50 and p95; writes the HALO-LATENCY line.
    @Test(.disabled("waits on CL-11")) func viewerDragLatency() {
        Issue.record("\(Self.prefix) isn't measured yet (CL-11)")
    }
}
#endif
