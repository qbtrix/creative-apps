// SnapLines.swift: the alignment-line engine (editor-kernel EK-29 stub; the
// snapping feature's SN-2 fills the body). Given the candidate frames, it
// finds the offset that lines a moving box's edges or centre up with one of
// theirs within a tolerance, and the lines to draw once it has snapped.
//
// Built once per gesture: each candidate's min, centre and max on both axes
// go into buckets 64 pt wide, keyed by Int(floor(v / 64)), each kept with
// the candidate's span on the other axis. A lookup reads only the buckets
// the tolerance reaches.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Alignment lines against a set of candidate frames.
public struct SnapLines: Sendable {
    /// One candidate line: its position on its axis and the candidate's
    /// span on the other axis.
    struct Entry: Sendable {
        var at: Double, from: Double, to: Double
    }

    /// The width of one bucket, in points.
    static let bucketSize = 64.0

    /// The frames the lines come from.
    let candidates: [SnapCandidate]
    /// The x lines and the y lines, each by bucket.
    let xBuckets: [Int: [Entry]], yBuckets: [Int: [Entry]]

    /// An engine over the candidates `c`.
    public init(_ c: [SnapCandidate]) {
        candidates = c
        var xs: [Int: [Entry]] = [:], ys: [Int: [Entry]] = [:]
        for candidate in c {
            let f = candidate.frame
            for v in [f.minX, (f.minX + f.maxX) / 2, f.maxX] {
                guard let key = Self.bucket(v) else { continue }
                xs[key, default: []].append(Entry(at: v, from: f.minY, to: f.maxY))
            }
            for v in [f.minY, (f.minY + f.maxY) / 2, f.maxY] {
                guard let key = Self.bucket(v) else { continue }
                ys[key, default: []].append(Entry(at: v, from: f.minX, to: f.maxX))
            }
        }
        (xBuckets, yBuckets) = (xs, ys)
    }

    /// The bucket `v` falls in; nil when `v` is not finite or too large for
    /// an `Int` key, so a bad frame never traps.
    static func bucket(_ v: Double) -> Int? {
        let key = (v / bucketSize).rounded(.down)
        guard key.isFinite, abs(key) < 1e15 else { return nil }
        return Int(key)
    }

    /// The lines on `axis` in the buckets from `v - reach` to `v + reach`.
    func nearby(_ axis: SnapLine.Axis, _ v: Double, reach: Double) -> [Entry] {
        let buckets = axis == .x ? xBuckets : yBuckets
        guard reach >= 0, let low = Self.bucket(v - reach), let high = Self.bucket(v + reach) else { return [] }
        if high - low >= buckets.count {
            return buckets.filter { (low...high).contains($0.key) }.flatMap(\.value)
        }
        return (low...high).flatMap { buckets[$0] ?? [] }
    }

    /// The smallest offset on `axis` that lines one of `values` (a box's
    /// edges and centre) up with a candidate within `tolerance` (inclusive);
    /// nil when none is that close. Two equally close lines on opposite
    /// sides give the negative offset.
    public func offset(_ axis: SnapLine.Axis, for values: [Double], tolerance: Double) -> Double? {
        var best: Double?
        for v in values {
            for entry in nearby(axis, v, reach: tolerance) {
                let d = entry.at - v
                guard abs(d) <= tolerance else { continue }
                if let current = best, abs(d) > abs(current) || (abs(d) == abs(current) && d >= current) { continue }
                best = d
            }
        }
        return best
    }

    /// The lines `box` sits on, to draw: one per position among its min,
    /// centre and max on each axis that a candidate line equals (to 0.001),
    /// spanning the box and every candidate on it. The x lines come first.
    public func lines(on box: Rect) -> [SnapLine] {
        let xs = [box.minX, (box.minX + box.maxX) / 2, box.maxX]
        let ys = [box.minY, (box.minY + box.maxY) / 2, box.maxY]
        return lines(.x, at: xs, span: (box.minY, box.maxY)) + lines(.y, at: ys, span: (box.minX, box.maxX))
    }

    /// The lines on `axis` at the positions `values`, each spanning `span`
    /// and the candidates on it.
    func lines(_ axis: SnapLine.Axis, at values: [Double], span: (Double, Double)) -> [SnapLine] {
        var out: [SnapLine] = []
        for v in values where !out.contains(where: { $0.at == v }) {
            let on = nearby(axis, v, reach: 0.001).filter { abs($0.at - v) < 0.001 }
            guard !on.isEmpty else { continue }
            let from = on.map(\.from).reduce(span.0, min), to = on.map(\.to).reduce(span.1, max)
            out.append(SnapLine(axis: axis, at: v, from: from, to: to))
        }
        return out
    }
}
