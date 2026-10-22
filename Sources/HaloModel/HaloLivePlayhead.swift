// HaloLivePlayhead.swift: a playing tick or a ruler scrub shown live, off the
// window's project (#4274, #4448). Each step is worked out on a copy of the
// window's project; the copy is what the viewer and playhead show, and the
// window's project changes only when the step is taken back (`take`): before
// the next command or edit, when play-once ends, or once a ruler drag has
// settled. A tick and a scrub are never pending together: a step of the other
// kind takes the pending one back first, so taking back replays exactly one
// step on the window's project. Never an undo step. Linux-safe.

public struct HaloLivePlayhead: Sendable, Equatable {
    /// A step the window shows live instead of writing.
    public enum Step: Sendable, Equatable {
        /// A refresh of playback at `now` seconds on the media clock.
        case tick(now: Double)
        /// A ruler drag sample on `frame`.
        case scrub(frame: Int)
    }

    /// What a step does: the project the window writes (nil: none) and the
    /// project shown live (nil: the window's own).
    public struct Outcome: Sendable, Equatable {
        public let write: HaloProject?
        public let shown: HaloProject?
    }

    /// Seconds a ruler drag rests before its frame is taken back.
    public static let settle = 0.2

    /// The step shown live and not yet in the window's project; nil when none.
    public private(set) var pending: Step?

    public init() {}

    /// `step` on the window's `model`, while `shown` is shown live (nil: the
    /// model itself). Nil when it changes nothing on screen or in the window.
    public mutating func apply(_ step: Step, model: HaloProject, shown: HaloProject?) -> Outcome? {
        var base = model, live = shown
        var wrote: HaloProject?
        if let pending, !pending.isKind(of: step) {
            wrote = take(model)
            base = wrote ?? model
            live = nil
        }
        var next = base
        switch step {
        case .tick(let now): next.tick(now: now)
        case .scrub(let frame): next.scrub(to: frame)
        }
        guard next != (live ?? base) else {
            return wrote == nil && live == shown ? nil : Outcome(write: wrote, shown: live)
        }
        if case .tick = step, !next.playback.playing {
            pending = nil
            return Outcome(write: next, shown: nil)
        }
        pending = step
        return Outcome(write: wrote, shown: next)
    }

    /// The window's `model` with the pending step written back, which clears
    /// it; nil when nothing is pending or the step changes nothing there.
    public mutating func take(_ model: HaloProject) -> HaloProject? {
        guard let step = pending else { return nil }
        pending = nil
        var next = model
        switch step {
        case .tick(let now): guard model.tickChanges(now: now) else { return nil }
            next.tick(now: now)
        case .scrub(let frame): guard model.scrubChanges(to: frame) else { return nil }
            next.scrub(to: frame)
        }
        return next
    }
}

extension HaloLivePlayhead.Step {
    /// Whether `other` is a step of the same kind (both ticks, or both scrubs).
    func isKind(of other: Self) -> Bool {
        switch (self, other) {
        case (.tick, .tick), (.scrub, .scrub): true
        default: false
        }
    }
}
