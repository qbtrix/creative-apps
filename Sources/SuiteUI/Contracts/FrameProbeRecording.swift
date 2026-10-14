// FrameProbeRecording.swift: UC17, the suite.perf contract. Samples, drawn
// frames and marks, their summaries, the published document, and
// FakeFrameProbe (reports every sample 0 frames late on purpose). Foundation
// only; verbatim from blueprint section 5.3. The live probe is SH-4.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct ProbeSample: Hashable, Sendable, Codable {
    public var series: String          // "bar-slider", "canvas-drag", ...
    public var eventTime: Double       // the input event's timestamp, seconds
    public var shownAt: Double         // the target timestamp of the first refresh that drew it
    public init(series: String, eventTime: Double, shownAt: Double) {
        self.series = series; self.eventTime = eventTime; self.shownAt = shownAt
    }
}

public struct ProbeSummary: Hashable, Sendable, Codable {
    public var count: Int
    public var p50FramesLate: Int
    public var p95FramesLate: Int
    public var valid: Bool             // at least 60 samples (section 7)
    public init(count: Int, p50FramesLate: Int, p95FramesLate: Int, valid: Bool) {
        self.count = count; self.p50FramesLate = p50FramesLate; self.p95FramesLate = p95FramesLate; self.valid = valid
    }
}

/// Frames drawn during a scroll or playback, which have no input event: intervals between drawn frames.
public struct FrameIntervalSummary: Hashable, Sendable, Codable {
    public var count: Int              // intervals measured
    public var p95Refreshes: Double    // p95 interval in refreshes (QB-S7: ≤ 1.5)
    public var dropped: Int            // refreshes with no new frame while one was due
    public var jitterP95: Double       // p95 of |interval − refresh|, seconds (QB-L4)
    public var valid: Bool             // at least 60 intervals
    public init(count: Int, p95Refreshes: Double, dropped: Int, jitterP95: Double, valid: Bool) {
        self.count = count; self.p95Refreshes = p95Refreshes; self.dropped = dropped; self.jitterP95 = jitterP95; self.valid = valid
    }
}

/// One in-app moment. Fades record a pair: `fade-start` and `fade-end` with the same series.
public struct ProbeMark: Hashable, Sendable, Codable {
    public var name: String            // "preview-before-mouse-up", "progress-shown", "fade-start", "fade-end", ...
    public var series: String
    public var time: Double
    public init(name: String, series: String, time: Double) { self.name = name; self.series = series; self.time = time }
}

/// The `suite.perf` document. Published under `-SuitePerfProbe` as the accessibility **label** (values can
/// read empty, #262) of a hidden element with identifier `suite.perf`; journeys decode it with this same
/// type, which the Journey template compiles from `Contracts/` (section 4.1).
public struct ProbeDocument: Hashable, Sendable, Codable {
    public var refreshInterval: Double
    public var samples: [ProbeSample]
    public var drawn: [String: [Double]]
    public var marks: [ProbeMark]
    public var latency: [String: ProbeSummary]           // per series, computed in the app
    public var intervals: [String: FrameIntervalSummary] // per series, computed in the app
    public init(refreshInterval: Double, samples: [ProbeSample], drawn: [String: [Double]], marks: [ProbeMark],
                latency: [String: ProbeSummary], intervals: [String: FrameIntervalSummary]) {
        self.refreshInterval = refreshInterval; self.samples = samples; self.drawn = drawn; self.marks = marks
        self.latency = latency; self.intervals = intervals
    }
}

public protocol FrameProbeRecording: Sendable {
    mutating func record(_ sample: ProbeSample)
    /// A frame of `series` drawn at the target timestamp `time` (scrolls, playback).
    mutating func drew(_ series: String, at time: Double)
    /// An in-app moment; every call is kept, in order.
    mutating func mark(_ name: String, series: String, at time: Double)
    /// Frames late = refreshes between the event and the refresh that showed it, at `refreshInterval` seconds.
    func summary(of series: String, refreshInterval: Double) -> ProbeSummary
    func intervals(of series: String, refreshInterval: Double) -> FrameIntervalSummary
    /// Everything recorded, with both summaries for every series.
    func document(refreshInterval: Double) -> ProbeDocument
    /// The `suite.perf` JSON: `document(refreshInterval:)` encoded.
    func encoded(refreshInterval: Double) throws -> Data
}

/// Keeps samples, frames and marks; reports every sample as 0 frames late.
public struct FakeFrameProbe: FrameProbeRecording {
    public private(set) var samples: [ProbeSample] = []
    public private(set) var marks: [ProbeMark] = []
    public init() {}
    public private(set) var drawn: [String: [Double]] = [:]
    public mutating func record(_ sample: ProbeSample) { samples.append(sample) }
    public mutating func drew(_ series: String, at time: Double) { drawn[series, default: []].append(time) }
    public mutating func mark(_ name: String, series: String, at time: Double) {
        marks.append(ProbeMark(name: name, series: series, time: time))
    }
    public func summary(of series: String, refreshInterval: Double) -> ProbeSummary {
        let n = samples.filter { $0.series == series }.count
        return ProbeSummary(count: n, p50FramesLate: 0, p95FramesLate: 0, valid: n >= 60)
    }
    /// Reports every interval as exactly one refresh, nothing dropped.
    public func intervals(of series: String, refreshInterval: Double) -> FrameIntervalSummary {
        let n = max((drawn[series]?.count ?? 0) - 1, 0)
        return FrameIntervalSummary(count: n, p95Refreshes: 1, dropped: 0, jitterP95: 0, valid: n >= 60)
    }
    public func document(refreshInterval: Double) -> ProbeDocument {
        let series = Set(samples.map(\.series)), drawnSeries = Set(drawn.keys)
        return ProbeDocument(
            refreshInterval: refreshInterval, samples: samples, drawn: drawn, marks: marks,
            latency: Dictionary(uniqueKeysWithValues: series.map { ($0, summary(of: $0, refreshInterval: refreshInterval)) }),
            intervals: Dictionary(uniqueKeysWithValues: drawnSeries.map { ($0, intervals(of: $0, refreshInterval: refreshInterval)) }))
    }
    public func encoded(refreshInterval: Double) throws -> Data { try JSONEncoder().encode(document(refreshInterval: refreshInterval)) }
}
