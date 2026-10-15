// FrameProbeTests.swift: SuiteFrameProbe's math equals a reference table
// (QB-S30) and its summary of 10,000 samples stays in budget (QB-S16). The
// samples are synthetic, so every p50, p95 and dropped count is known.
// No SwiftUI here. macOS only.
import Foundation
import SuiteUI
import Testing

@Suite struct FrameProbeTests {
    /// 100 samples, 10 each 0...9 frames late at 60 Hz; each is shown a quarter refresh after its whole frames,
    /// so at 120 Hz the same seconds read twice as many frames late.
    static func latencyProbe() -> SuiteFrameProbe {
        var probe = SuiteFrameProbe()
        for i in 0..<100 {
            let event = 10 + Double(i) * 0.05
            probe.record(ProbeSample(series: "bar-slider", eventTime: event, shownAt: event + (Double(i / 10) + 0.25) / 60))
        }
        return probe
    }

    /// 101 frames: 90 intervals of one refresh, 7 of two and 3 of three, so 13 refreshes dropped.
    static func intervalProbe(refreshInterval r: Double) -> SuiteFrameProbe {
        var probe = SuiteFrameProbe()
        var refresh = 0
        probe.drew("playback", at: 0)
        for i in 0..<100 {
            refresh += i < 90 ? 1 : (i < 97 ? 2 : 3)
            probe.drew("playback", at: Double(refresh) * r)
        }
        return probe
    }

    // QB-S30: series, refresh, p50, p95 frames late; p95 refreshes, dropped, jitter p95 in refreshes.
    static let table: [(hz: Double, p50: Int, p95: Int, p95Refreshes: Double, dropped: Int, jitter: Double)] = [
        (60, 4, 9, 2, 13, 1),
        (120, 8, 18, 2, 13, 1),
    ]

    @Test func referenceTable() throws {
        let latency = Self.latencyProbe()
        for row in Self.table {
            let r = 1 / row.hz
            let summary = latency.summary(of: "bar-slider", refreshInterval: r)
            #expect(summary == ProbeSummary(count: 100, p50FramesLate: row.p50, p95FramesLate: row.p95, valid: true),
                    "\(row.hz) Hz")
            let frames = Self.intervalProbe(refreshInterval: r).intervals(of: "playback", refreshInterval: r)
            #expect(frames.count == 100 && frames.valid)
            #expect(frames.dropped == row.dropped, "\(row.hz) Hz")
            #expect(abs(frames.p95Refreshes - row.p95Refreshes) < 1e-9, "\(row.hz) Hz")
            #expect(abs(frames.jitterP95 - row.jitter * r) < 1e-9, "\(row.hz) Hz")
        }

        // A non-finite time is dropped, wherever it appears.
        var probe = latency
        probe.record(ProbeSample(series: "bar-slider", eventTime: .nan, shownAt: 1))
        probe.record(ProbeSample(series: "bar-slider", eventTime: 1, shownAt: .infinity))
        probe.drew("playback", at: -.infinity)
        probe.mark("fade-start", series: "chip", at: .nan)
        #expect(probe.samples.count == 100 && probe.drawn.isEmpty && probe.marks.isEmpty)

        // A refresh interval of 0 (or not a number) is invalid and never divides.
        for bad: Double in [0, -1.0 / 60, .nan] {
            let none = probe.summary(of: "bar-slider", refreshInterval: bad)
            #expect(none == ProbeSummary(count: 100, p50FramesLate: 0, p95FramesLate: 0, valid: false))
            let frames = Self.intervalProbe(refreshInterval: 1.0 / 60).intervals(of: "playback", refreshInterval: bad)
            #expect(frames == FrameIntervalSummary(count: 100, p95Refreshes: 0, dropped: 0, jitterP95: 0, valid: false))
        }

        // Under 60 samples reads invalid; no samples at all gives empty summaries.
        var short = SuiteFrameProbe()
        for i in 0..<59 { short.record(ProbeSample(series: "drag", eventTime: Double(i), shownAt: Double(i))) }
        #expect(!short.summary(of: "drag", refreshInterval: 1.0 / 60).valid)
        let empty = SuiteFrameProbe().document(refreshInterval: 1.0 / 60)
        #expect(empty.latency.isEmpty && empty.intervals.isEmpty)

        // A disabled probe records nothing; only -SuitePerfProbe enables one from launch arguments.
        var off = SuiteFrameProbe(arguments: ["FlareApp"])
        off.record(ProbeSample(series: "drag", eventTime: 0, shownAt: 0.1))
        off.drew("playback", at: 0)
        off.mark("progress-shown", series: "export", at: 0)
        #expect(off.samples.isEmpty && off.drawn.isEmpty && off.marks.isEmpty)
        #expect(SuiteFrameProbe(arguments: ["FlareApp", "-SuitePerfProbe"]).isEnabled)

        // The display's interval is used when it is a positive number, else 60 Hz.
        #expect(SuiteFrameProbe.refreshInterval(fromScreen: 1.0 / 120) == 1.0 / 120)
        #expect(SuiteFrameProbe.refreshInterval(fromScreen: nil) == 1.0 / 60)
        #expect(SuiteFrameProbe.refreshInterval(fromScreen: 0) == 1.0 / 60)

        // JSON round trip: the encoded document decodes to the same document, marks in order.
        var full = Self.intervalProbe(refreshInterval: 1.0 / 60)
        for sample in latency.samples { full.record(sample) }
        full.mark("fade-start", series: "chip", at: 2)
        full.mark("fade-end", series: "chip", at: 2.14)
        let document = full.document(refreshInterval: 1.0 / 60)
        let decoded = try JSONDecoder().decode(ProbeDocument.self, from: full.encoded(refreshInterval: 1.0 / 60))
        #expect(decoded == document)
        #expect(decoded.marks.map(\.name) == ["fade-start", "fade-end"])
        #expect(decoded.latency["bar-slider"]?.p95FramesLate == 9 && decoded.intervals["playback"]?.dropped == 13)
        #expect(try JSONDecoder().decode(ProbeDocument.self, from: Data(full.json(refreshInterval: 1.0 / 60).utf8)) == document)
    }

    /// The summary's percentiles equal a sort-and-pick reference, with small lates and with outliers
    /// thousands of frames late, at every count from 1 sample up.
    @Test func summaryMatchesSortedReference() {
        let r = 1.0 / 60
        for (n, outlier) in [(1, 0), (2, 0), (59, 0), (100, 0), (997, 0), (100, 50_000), (5_000, 9_000)] {
            var probe = SuiteFrameProbe()
            var lates: [Int] = []
            for i in 0..<n {
                let late = outlier > 0 && i % 10 == 3 ? outlier + i : (i * 37) % 23
                lates.append(late)
                let event = Double(i)
                probe.record(ProbeSample(series: "drag", eventTime: event, shownAt: event + (Double(late) + 0.5) * r))
            }
            lates.sort()
            func rank(_ p: Double) -> Int { lates[min(max(Int((p * Double(n)).rounded(.up)), 1), n) - 1] }
            let summary = probe.summary(of: "drag", refreshInterval: r)
            #expect(summary.count == n && summary.p50FramesLate == rank(0.5) && summary.p95FramesLate == rank(0.95),
                    "\(n) samples, outlier \(outlier)")
        }
    }

    // QB-S16: summary over 10,000 samples. After 10 warm-up runs, 100 runs are each timed in this thread's
    // CPU time, so time the scheduler gives other tests (they run in parallel) isn't counted: their median and
    // p95 stay within 20 ms (the debug gate; target 2 ms). The work takes about 1.3 ms in a debug build, so the
    // 20 ms gate alone can't see a 2x slowdown; each run is also paired with `framesLateReference`, timed right
    // after it, and the summary's median and p95 stay within 2.5x the reference's. Measured on Linux, debug:
    // 1.6 to 1.7x idle and with four copies running at once; doing the summary twice per run gives 3.1 to 3.4x.
    @Test func summaryWithinBudget() {
        var probe = SuiteFrameProbe()
        var samples: [ProbeSample] = []
        for i in 0..<10_000 {
            let event = Double(i) / 120
            let sample = ProbeSample(series: "canvas-drag", eventTime: event, shownAt: event + Double(i % 7) / 60)
            probe.record(sample)
            samples.append(sample)
        }
        let r = 1.0 / 60
        var last = ProbeSummary(count: 0, p50FramesLate: 0, p95FramesLate: 0, valid: false)
        var runs: [Double] = []
        var references: [Double] = []
        for run in 0..<110 {
            let start = Self.threadCPUSeconds()
            last = probe.summary(of: "canvas-drag", refreshInterval: r)
            let middle = Self.threadCPUSeconds()
            let lates = Self.framesLateReference(samples, series: "canvas-drag", refreshInterval: r)
            let end = Self.threadCPUSeconds()
            #expect(lates == 10_000)
            if run >= 10 {
                runs.append(middle - start)
                references.append(end - middle)
            }
        }
        runs.sort()
        references.sort()
        let (median, p95) = (runs[49], runs[94])
        let (refMedian, refP95) = (max(references[49], 1e-6), max(references[94], 1e-6))
        print("QB-S16 summary cpu median \(median * 1000) ms, p95 \(p95 * 1000) ms; reference median "
              + "\(refMedian * 1000) ms, p95 \(refP95 * 1000) ms; ratio \(median / refMedian), \(p95 / refP95)")
        #expect(last.count == 10_000 && last.valid)
        #expect(median <= 0.020, "median \(median * 1000) ms")
        #expect(p95 <= 0.020, "p95 \(p95 * 1000) ms")
        #expect(median / refMedian <= 2.5, "median \(median / refMedian)x the reference")
        #expect(p95 / refP95 <= 2.5, "p95 \(p95 / refP95)x the reference")
    }

    /// The summary's first pass without the probe: frames late for every sample of `series`, by the same
    /// formula, into an array. No percentiles. Returns how many it kept.
    static func framesLateReference(_ samples: [ProbeSample], series: String, refreshInterval r: Double) -> Int {
        var lates: [Int] = []
        lates.reserveCapacity(samples.count)
        for sample in samples where sample.series == series {
            let refreshes = ((sample.shownAt - sample.eventTime) / r).rounded(.up)
            lates.append(refreshes > 1 ? Int(refreshes) - 1 : 0)
        }
        return lates.count
    }

    /// This thread's CPU time in seconds.
    static func threadCPUSeconds() -> Double {
        var now = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &now)
        return Double(now.tv_sec) + Double(now.tv_nsec) / 1_000_000_000
    }
}
