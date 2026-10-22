// HaloInspectorScrub.swift: the inspector bar scrub's coalescer (CL-probe,
// #4275, #1297). Writing the live preview per pointer sample redrew the
// viewer per sample, 47 to 62 frames behind. Each sample lands here instead
// (the bar's latest value, the event's time); each refresh takes at most one
// value to write and the events it shows. The first sample asks for a
// refresh, an idle refresh stops asking, and a sample `longestWait` after the
// last frame writes at once, for a link that never fires (a headless runner).
// Times are seconds on one clock; Linux-safe (HaloInspectorScrubTests).

/// What one refresh of a bar scrub writes and shows.
public struct HaloScrubFrame: Sendable, Hashable {
    /// The latest value to write; nil when none came since the last refresh.
    public let value: Double?
    /// The input event times this refresh shows, oldest first, each once.
    public let events: [Double]

    public init(value: Double?, events: [Double]) {
        self.value = value
        self.events = events
    }

    /// Nothing came since the last refresh.
    public var isEmpty: Bool { value == nil && events.isEmpty }
}

/// What the bar does after one sample.
public enum HaloScrubStep: Sendable, Hashable {
    /// Nothing: the refresh asked for will write it.
    case wait
    /// Ask for a refresh: none is asked for yet.
    case askRefresh
    /// Take a frame now (`refresh(at:)`): the asked-for refresh is late.
    case writeNow
}

/// One bar scrub's samples between refreshes.
public struct HaloInspectorScrub: Sendable, Hashable {
    /// How long a sample waits for a refresh before it writes at once: a
    /// 60 Hz refresh and a half, so a live link always comes first.
    public static let longestWait = 0.025
    /// The latest value the bar took that no refresh has written yet.
    public private(set) var pending: Double?
    /// Input event times no refresh has shown yet, oldest first, each once.
    public private(set) var waiting: [Double] = []
    /// Whether a refresh is asked for: from the first sample until a refresh finds nothing.
    public private(set) var awaitsRefresh = false
    /// When the last frame was taken, or the first refresh asked for.
    public private(set) var lastFrame: Double?

    public init() {}

    /// One pointer sample at `eventTime`, taken at `now`, with the bar's new
    /// value, or nil when the pointer moved but the value didn't. Two calls
    /// for the same event (the bar's value and its drag) keep its time once;
    /// a time that isn't finite is not kept.
    public mutating func take(_ value: Double?, at eventTime: Double, now: Double) -> HaloScrubStep {
        if let value { pending = value }
        if eventTime.isFinite, waiting.last != eventTime { waiting.append(eventTime) }
        guard awaitsRefresh else {
            awaitsRefresh = true
            lastFrame = now
            return .askRefresh
        }
        guard let lastFrame, now - lastFrame >= Self.longestWait else { return .wait }
        return .writeNow
    }

    /// One refresh at `now`: the value to write once and the events it
    /// shows. A refresh that finds nothing stops asking for refreshes.
    public mutating func refresh(at now: Double) -> HaloScrubFrame {
        let frame = HaloScrubFrame(value: pending, events: waiting)
        pending = nil
        waiting = []
        lastFrame = now
        if frame.isEmpty { awaitsRefresh = false }
        return frame
    }

    /// The drag ended: what no refresh took yet, and no refresh asked for.
    public mutating func end() -> HaloScrubFrame {
        let frame = HaloScrubFrame(value: pending, events: waiting)
        self = Self()
        return frame
    }
}
