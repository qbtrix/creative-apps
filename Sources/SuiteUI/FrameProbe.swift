// FrameProbe.swift: SuiteFrameProbe, the live FrameProbeRecording (UC17,
// QH-1, #330). It keeps input samples, drawn frames and marks, and turns them
// into frames late (p50, p95 by nearest rank) and frame intervals (p95 in
// refreshes, dropped refreshes, jitter). A non-finite time is dropped when
// recorded, a refresh interval that is not a positive number gives
// `valid: false` and never divides, and a disabled probe records nothing.
// SuitePerfElement publishes the `suite.perf` JSON as the accessibility label
// of a hidden element; it is shown only under `-SuitePerfProbe` (SH-5's
// `.suiteProbes()` places it). The math is Foundation only (FrameProbeTests).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteFrameProbe: FrameProbeRecording {
    /// The launch flag that turns the probe on and publishes `suite.perf`.
    public static let launchFlag = "-SuitePerfProbe"
    /// The refresh interval used when the display's is unknown: 60 Hz.
    public static let fallbackRefreshInterval = 1.0 / 60.0
    /// A summary is valid with at least this many samples or intervals.
    public static let minimumCount = 60

    public let isEnabled: Bool
    public private(set) var samples: [ProbeSample] = []
    public private(set) var drawn: [String: [Double]] = [:]
    public private(set) var marks: [ProbeMark] = []

    public init(enabled: Bool = true) { isEnabled = enabled }

    /// A probe that records only when `arguments` carry `-SuitePerfProbe`.
    public init(arguments: [String]) { self.init(enabled: Self.isRequested(by: arguments)) }

    public static func isRequested(by arguments: [String]) -> Bool { arguments.contains(launchFlag) }

    /// The display's refresh interval when it is a positive number, else 60 Hz.
    /// On macOS pass `NSScreen.minimumRefreshInterval` of the window's screen.
    public static func refreshInterval(fromScreen interval: Double?) -> Double {
        guard let interval, interval.isFinite, interval > 0 else { return fallbackRefreshInterval }
        return interval
    }

    public mutating func record(_ sample: ProbeSample) {
        guard isEnabled, sample.eventTime.isFinite, sample.shownAt.isFinite else { return }
        samples.append(sample)
    }

    public mutating func drew(_ series: String, at time: Double) {
        guard isEnabled, time.isFinite else { return }
        drawn[series, default: []].append(time)
    }

    public mutating func mark(_ name: String, series: String, at time: Double) {
        guard isEnabled, time.isFinite else { return }
        marks.append(ProbeMark(name: name, series: series, time: time))
    }

    /// Refreshes between the event and the refresh that showed it; 0 when shown by the next refresh.
    public static func framesLate(_ sample: ProbeSample, refreshInterval r: Double) -> Int {
        let refreshes = ((sample.shownAt - sample.eventTime) / r).rounded(.up)
        guard refreshes.isFinite, refreshes > 1 else { return 0 }
        return refreshes < Double(Int.max) ? Int(refreshes) - 1 : Int.max
    }

    public func summary(of series: String, refreshInterval r: Double) -> ProbeSummary {
        guard Self.usable(r) else {
            let count = samples.reduce(0) { $0 + ($1.series == series ? 1 : 0) }
            return ProbeSummary(count: count, p50FramesLate: 0, p95FramesLate: 0, valid: false)
        }
        var lates: [Int] = []
        lates.reserveCapacity(samples.count)
        for sample in samples where sample.series == series { lates.append(Self.framesLate(sample, refreshInterval: r)) }
        lates.sort()
        return ProbeSummary(count: lates.count, p50FramesLate: Self.nearestRank(lates, 0.5) ?? 0,
                            p95FramesLate: Self.nearestRank(lates, 0.95) ?? 0, valid: lates.count >= Self.minimumCount)
    }

    public func intervals(of series: String, refreshInterval r: Double) -> FrameIntervalSummary {
        let times = (drawn[series] ?? []).sorted()
        let diffs = zip(times.dropFirst(), times).map { $0 - $1 }
        guard Self.usable(r) else {
            return FrameIntervalSummary(count: diffs.count, p95Refreshes: 0, dropped: 0, jitterP95: 0, valid: false)
        }
        let refreshes = diffs.map { $0 / r }
        let dropped = refreshes.reduce(0) { $0 + max(0, Int($1.rounded()) - 1) }
        return FrameIntervalSummary(
            count: diffs.count, p95Refreshes: Self.nearestRank(refreshes.sorted(), 0.95) ?? 0, dropped: dropped,
            jitterP95: Self.nearestRank(diffs.map { abs($0 - r) }.sorted(), 0.95) ?? 0,
            valid: diffs.count >= Self.minimumCount)
    }

    public func document(refreshInterval r: Double) -> ProbeDocument {
        let latency = Set(samples.map(\.series)).map { ($0, summary(of: $0, refreshInterval: r)) }
        let frames = drawn.keys.map { ($0, intervals(of: $0, refreshInterval: r)) }
        return ProbeDocument(refreshInterval: r, samples: samples, drawn: drawn, marks: marks,
                             latency: Dictionary(uniqueKeysWithValues: latency),
                             intervals: Dictionary(uniqueKeysWithValues: frames))
    }

    public func encoded(refreshInterval r: Double) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(document(refreshInterval: r))
    }

    /// The `suite.perf` label text: the encoded document, or `{}` when it can't encode.
    public func json(refreshInterval r: Double) -> String {
        guard let data = try? encoded(refreshInterval: r) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    static func usable(_ r: Double) -> Bool { r.isFinite && r > 0 }

    /// The nearest-rank percentile of sorted values: the value at rank ⌈p·n⌉; nil when empty.
    static func nearestRank<T>(_ sorted: [T], _ p: Double) -> T? {
        guard !sorted.isEmpty else { return nil }
        let rank = Int((p * Double(sorted.count)).rounded(.up))
        return sorted[min(max(rank, 1), sorted.count) - 1]
    }
}

#if canImport(SwiftUI)
import SwiftUI

/// The hidden `suite.perf` element: no pixels, no hits, its label the probe's JSON.
public struct SuitePerfElement: View {
    public static let identifier = "suite.perf"
    let json: String

    public init(probe: SuiteFrameProbe, refreshInterval: Double) {
        json = probe.json(refreshInterval: refreshInterval)
    }

    public var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: json))
            .accessibilityIdentifier(Self.identifier)
    }
}
#endif
