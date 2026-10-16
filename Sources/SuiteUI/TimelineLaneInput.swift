// TimelineLaneInput.swift: a TimelineLane's pointer handling. A press within
// half the 16 pt key token of a key lands on that key (TimelineLaneHit; the
// nearer key wins, B11), anywhere else on the bed. TimelineLanePress says what
// a press does (TL-11): on a key it calls onPickKeyframe with TimelinePick's
// mode for the held modifiers, and a plain press also onSelectKeyframe; on the
// bed onSelectTrack and onPickKeyframe(id, nil, .replace) (B5). A right press
// picks an unpicked key under the pointer so the host's context menu acts on
// it, and leaves a picked one alone (B6): a local AppKit monitor sees the
// right button go down (passing the event on to the menu) and the lane acts
// on its hovered key. It owns the lane's hover, presentation state: which lane the pointer is
// over and the key under it. A hover sample writes only when that changes,
// and the change fades with SuiteMotion.state (at once under Reduce Motion),
// reporting `fade-start` and `fade-end` marks (series `timeline-hover`) to
// `timelineFadeMark`. The hover reaches only this lane, through the
// environment, so no other lane redraws.
import AppKit
import SwiftUI

struct TimelineLaneInput<ID: Hashable & Sendable>: ViewModifier {
    let track: TimelineTrack<ID>
    let mapping: FrameMapping
    let actions: TimelineLaneActions<ID>
    @State private var hover: TimelineLaneHover?
    /// Right presses seen while the pointer was over this lane.
    @State private var rightPresses = 0
    @State private var monitor: Any?
    @Environment(\.suiteReduceMotion) private var reduceMotion
    @Environment(\.timelineFadeMark) private var fadeMark

    func body(content: Content) -> some View {
        content
            .environment(\.timelineLaneHover, hover)
            .onTapGesture { location in
                let target = TimelineLanePress.target(atX: location.x, on: track, mapping: mapping)
                TimelineLanePress.press(
                    target, modifiers: Self.modifiers(NSEvent.modifierFlags), on: track, actions: actions)
            }
            .onChange(of: rightPresses) {
                let target: TimelineLanePress.Target = hover?.key.map { .key($0) } ?? .bed
                TimelineLanePress.rightPress(target, on: track, actions: actions)
            }
            .onAppear(perform: watchRightPresses)
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
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

    /// Counts a right button press while the pointer is over this lane; the
    /// event goes on, so the host's context menu still opens.
    private func watchRightPresses() {
        guard monitor == nil else { return }
        let hovering = $hover
        let presses = $rightPresses
        monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            MainActor.assumeIsolated {
                if hovering.wrappedValue != nil { presses.wrappedValue &+= 1 }
            }
            return event
        }
    }

    /// The pick rule's modifiers from AppKit's.
    private static func modifiers(_ flags: NSEvent.ModifierFlags) -> KeyModifiers {
        var modifiers: KeyModifiers = []
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        return modifiers
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

/// The strip's closures a lane press calls.
struct TimelineLaneActions<ID: Hashable & Sendable> {
    let onSelectKeyframe: @MainActor (ID, Int) -> Void
    let onSelectTrack: @MainActor (ID) -> Void
    let onPickKeyframe: @MainActor (ID, Int?, PickMode) -> Void
}

/// What a press on a lane does, with no view (TL-11; B5, B6).
@MainActor enum TimelineLanePress {
    /// Where a press lands: on a key's frame, or on the bed.
    enum Target: Equatable, Sendable {
        case key(Int)
        case bed
    }

    /// The key within half the 16 pt token of lane x `x`, else the bed.
    static func target<ID>(atX x: CGFloat, on track: TimelineTrack<ID>, mapping: FrameMapping) -> Target {
        TimelineLaneHit.key(atX: x, on: track, mapping: mapping).map { .key($0) } ?? .bed
    }

    /// A left press: a key is picked by the pick rule (a plain press also
    /// selects it); the bed selects the track and clears the pick (B5).
    static func press<ID>(
        _ target: Target, modifiers: KeyModifiers, on track: TimelineTrack<ID>, actions: TimelineLaneActions<ID>
    ) {
        switch target {
        case .key(let frame):
            actions.onPickKeyframe(track.id, frame, TimelinePick.mode(pressWith: modifiers))
            if modifiers.isEmpty { actions.onSelectKeyframe(track.id, frame) }
        case .bed:
            actions.onSelectTrack(track.id)
            actions.onPickKeyframe(track.id, nil, .replace)
        }
    }

    /// A right press: an unpicked key replaces the pick; a picked key or the bed changes nothing (B6).
    static func rightPress<ID>(_ target: Target, on track: TimelineTrack<ID>, actions: TimelineLaneActions<ID>) {
        guard case .key(let frame) = target,
              let mode = TimelinePick.mode(rightPressOnPicked: track.pickedFrames.contains(frame)) else { return }
        actions.onPickKeyframe(track.id, frame, mode)
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
