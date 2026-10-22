// HaloDragPacer.swift: viewer-drag moves coalesced to at most one write per
// display refresh (#4276). Moves inside a refresh are held, the latest wins,
// `flush` writes it once due, and `end` hands back the exact last point for
// the drag's one "Move" step. Seconds on any monotonic clock. Linux-safe.

public struct HaloDragPacer: Sendable, Equatable {
    /// Seconds between writes: one display refresh.
    public let interval: Double
    /// The latest move not yet written; nil when the last move was written.
    public private(set) var pending: HaloPoint?
    /// When the last write happened; nil before the first.
    public private(set) var writtenAt: Double?
    /// The latest move seen, written or not.
    public private(set) var latest: HaloPoint?

    /// At most one write per `interval`; 60 Hz for a bad interval.
    public init(interval: Double) {
        self.interval = interval.isFinite && interval > 0 ? interval : 1.0 / 60
    }

    /// The drag moved to `point` at `now`: the point to write now, or nil
    /// when a write already happened this refresh (it is held; the latest wins).
    public mutating func move(to point: HaloPoint, now: Double) -> HaloPoint? {
        latest = point
        if let at = writtenAt, now - at < interval {
            pending = point
            return nil
        }
        pending = nil
        writtenAt = now
        return point
    }

    /// When the held point may be written; nil with nothing held.
    public var due: Double? {
        guard pending != nil, let at = writtenAt else { return nil }
        return at + interval
    }

    /// The held point once its refresh is due at `now`, written once; else nil.
    public mutating func flush(now: Double) -> HaloPoint? {
        guard let point = pending, let due, now >= due else { return nil }
        pending = nil
        writtenAt = now
        return point
    }

    /// Mouse-up: the drag's exact last point (nil if it never moved); starts over.
    public mutating func end() -> HaloPoint? {
        let point = latest
        self = HaloDragPacer(interval: interval)
        return point
    }

    /// Escape: drops everything held.
    public mutating func cancel() {
        self = HaloDragPacer(interval: interval)
    }
}
