// TimelineLaneInput.swift: a TimelineLane's pointer handling. A press within
// half the 16 pt key token of a key calls onSelectKeyframe with that frame
// (TimelineLaneHit; the nearer key wins, B11); a press elsewhere does nothing
// yet. It owns the lane's hover, presentation state: which lane the pointer is
// over and the key under it. A hover sample writes only when that changes,
// and the change fades with SuiteMotion.state (at once under Reduce Motion),
// reporting `fade-start` and `fade-end` marks (series `timeline-hover`) to
// `timelineFadeMark`. The hover reaches only this lane, through the
// environment, so no other lane redraws.
import SwiftUI

struct TimelineLaneInput<ID: Hashable & Sendable>: ViewModifier {
    let track: TimelineTrack<ID>
    let mapping: FrameMapping
    let onSelectKeyframe: @MainActor (ID, Int) -> Void
    @State private var hover: TimelineLaneHover?
    @Environment(\.suiteReduceMotion) private var reduceMotion
    @Environment(\.timelineFadeMark) private var fadeMark

    func body(content: Content) -> some View {
        content
            .environment(\.timelineLaneHover, hover)
            .onTapGesture { location in
                if let frame = TimelineLaneHit.key(atX: location.x, on: track, mapping: mapping) {
                    onSelectKeyframe(track.id, frame)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    setHover(TimelineLaneHover(key: TimelineLaneHit.key(atX: location.x, on: track, mapping: mapping)))
                case .ended:
                    setHover(nil)
                }
            }
    }

    /// Writes `new` only when it differs from what is shown, fading the change.
    private func setHover(_ new: TimelineLaneHover?) {
        guard new != hover else { return }
        let mark = fadeMark
        mark?.record(ProbeMark(name: "fade-start", series: "timeline-hover", time: ProcessInfo.processInfo.systemUptime))
        withAnimation(SuiteMotion.state(reduceMotion: reduceMotion)) {
            hover = new
        } completion: {
            mark?.record(ProbeMark(name: "fade-end", series: "timeline-hover", time: ProcessInfo.processInfo.systemUptime))
        }
    }
}

/// The key a press or the pointer at lane x `x` lands on, with no view.
enum TimelineLaneHit {
    /// The nearest key within half the 16 pt token of `x`, or nil.
    static func key<ID>(atX x: CGFloat, on track: TimelineTrack<ID>, mapping: FrameMapping) -> Int? {
        let local = Double(x - timelineInset)
        return mapping.keyframe(nearX: local, in: track.keyframes, tolerance: Double(SuiteSize.timelineKeyframeHit / 2))
    }
}

/// A lane's hover: the pointer is over the lane, and `key` is the key under it.
struct TimelineLaneHover: Equatable, Sendable {
    var key: Int?
}

/// Where hover fades report their marks; a probe host sets it.
struct TimelineFadeMark: Sendable {
    let record: @MainActor @Sendable (ProbeMark) -> Void
}

extension EnvironmentValues {
    /// The hover of the lane this sits in; nil when the pointer is elsewhere.
    var timelineLaneHover: TimelineLaneHover? {
        get { self[TimelineLaneHoverKey.self] }
        set { self[TimelineLaneHoverKey.self] = newValue }
    }

    /// Where a lane's hover fade reports `fade-start` and `fade-end`; nil records nothing.
    var timelineFadeMark: TimelineFadeMark? {
        get { self[TimelineFadeMarkKey.self] }
        set { self[TimelineFadeMarkKey.self] = newValue }
    }
}

private struct TimelineLaneHoverKey: EnvironmentKey {
    static let defaultValue: TimelineLaneHover? = nil
}

private struct TimelineFadeMarkKey: EnvironmentKey {
    static let defaultValue: TimelineFadeMark? = nil
}
