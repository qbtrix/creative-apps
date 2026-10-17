// TimelineLaneInput.swift: a TimelineLane's pointer handling. A press within
// half the 16 pt key token of a key lands on that key (TimelineLaneHit; the
// nearer key wins, B11), anywhere else on the bed. TimelineLanePress says what
// a press does (TL-11): on a key it calls onPickKeyframe with TimelinePick's
// mode for the held modifiers, and a plain press also onSelectKeyframe; on the
// bed onSelectTrack and onPickKeyframe(id, nil, .replace) (B5). A right press
// picks an unpicked key under the pointer so the host's context menu acts on
// it, and leaves a picked one alone (B6): a local AppKit monitor sees the
// right button go down (passing the event on to the menu) and the lane acts
// on its hovered key. The press and its drag are one gesture (TL-14): a press
// on an unpicked key picks it at once, a picked key's pick waits for a release
// that didn't move, and a drag moves the picked keys (TimelineKeyDrag: snapped
// to the playhead, the group clamped, onMoveKeyframes only on a frame step,
// onEndKeyDrag once, after the release's own sample has moved them; Escape
// sends the steps back and ends it). A time pill
// above the grabbed key shows its frame while it moves, and each step reports
// a `step` mark in series `key-drag`. The drag's bookkeeping sits in a box
// SwiftUI doesn't watch; only the pill's frame is state, written per step.
// A press within 6 pt of a clip's start or end tick, and not on a key, trims
// that end (TL-15; TimelineTrimDrag): the edge follows the pointer, snapped to
// the playhead and kept by the trim rule, onTrim only when the edge's frame
// changes, onEndTrim once on release; the same pill shows the edge's frame,
// and the pointer over a clip end is the column-resize pointer.
// A press first takes the strip's focus (TimelineFocusClaim, #1813).
// It owns the lane's hover, presentation state: which lane the pointer is
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
    let playhead: Int
    let actions: TimelineLaneActions<ID>
    @State private var hover: TimelineLaneHover?
    /// The press in progress; not observed, so a pointer sample writes no state.
    @State private var press = TimelineLanePressBox()
    /// The grabbed key's frame while it moves; the pill shows it.
    @State private var pillFrame: Int?
    /// Right presses seen while the pointer was over this lane.
    @State private var rightPresses = 0
    /// The pointer is over a clip end, so it shows the resize pointer.
    @State private var overClipEnd = false
    @State private var monitor: Any?
    @Environment(\.suiteReduceMotion) private var reduceMotion
    @Environment(\.timelineFadeMark) private var fadeMark
    @Environment(\.timelineFocusClaim) private var focusClaim

    func body(content: Content) -> some View {
        content
            .environment(\.timelineLaneHover, hover)
            .overlay(alignment: .topLeading) { pill }
            .pointerStyle(overClipEnd ? .columnResize : nil)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in dragChanged(value) }
                    .onEnded { value in dragEnded(value) })
            .onChange(of: rightPresses) {
                let target: TimelineLanePress.Target = hover?.key.map { .key($0) } ?? .bed
                TimelineLanePress.rightPress(target, on: track, actions: actions)
            }
            .onAppear(perform: watchRightPresses)
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
                press.stopWatchingEscape()
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let key = TimelineLaneHit.key(atX: location.x, on: track, mapping: mapping)
                    setHover(TimelineLaneHover(key: key))
                    let onEnd = key == nil && TimelineLaneHit.clipEnd(atX: location.x, on: track, mapping: mapping) != nil
                    if onEnd != overClipEnd { overClipEnd = onEnd }
                case .ended:
                    setHover(nil)
                    if overClipEnd { overClipEnd = false }
                }
            }
    }

    /// The time pill over the grabbed key or clip end while it moves.
    @ViewBuilder private var pill: some View {
        if let pillFrame {
            Text(TimelineTime.label(frame: pillFrame, fps: 0, unit: .frames))
                .font(SuiteFont.pill)
                .foregroundStyle(SuiteColor.overlayPaper)
                .padding(SuiteInset.pill)
                .frame(height: SuiteSize.pill)
                .background(alignment: .center) { Capsule().fill(SuiteColor.accentFill) }
                .fixedSize()
                .position(x: tickX(mapping, pillFrame), y: -SuiteSize.pill / 2)
                .allowsHitTesting(false)
        }
    }

    /// The first sample classifies the press (key, clip end, else bed) and may
    /// start a key drag or a trim; later samples move it.
    private func dragChanged(_ value: DragGesture.Value) {
        if !press.active {
            focusClaim?.claim()
            press.active = true
            press.modifiers = Self.modifiers(NSEvent.modifierFlags)
            press.target = TimelineLanePress.target(atX: value.startLocation.x, on: track, mapping: mapping)
            press.drag = TimelineLanePress.begin(
                press.target, modifiers: press.modifiers, on: track, playhead: playhead, mapping: mapping,
                actions: actions)
            if press.drag != nil { watchEscape() }
            press.trim = TimelineLanePress.beginTrim(press.target, playhead: playhead, mapping: mapping)
            return
        }
        if var trim = press.trim {
            let stepped = trim.move(dx: Double(value.translation.width), id: track.id, actions: actions)
            press.trim = trim
            if stepped, pillFrame != trim.frame { pillFrame = trim.frame }
            return
        }
        guard var drag = press.drag else { return }
        let stepped = drag.move(dx: Double(value.translation.width), actions: actions)
        press.drag = drag
        if stepped { showStep(drag) }
    }

    /// The release: takes the last sample's move (#1796), then ends a drag once, or acts as a click.
    private func dragEnded(_ value: DragGesture.Value) {
        defer {
            press.reset()
            pillFrame = nil
        }
        guard press.active else { return }
        var click = true
        if var drag = press.drag {
            click = drag.release(atDX: Double(value.translation.width), actions: actions)
            press.drag = drag
        }
        if var trim = press.trim {
            click = trim.release(atDX: Double(value.translation.width), id: track.id, actions: actions)
            press.trim = trim
        }
        if click { TimelineLanePress.press(press.target, modifiers: press.modifiers, on: track, actions: actions) }
    }

    /// Writes the pill's frame and reports the step.
    private func showStep(_ drag: TimelineKeyDrag) {
        if pillFrame != drag.frame { pillFrame = drag.frame }
        fadeMark?.record(ProbeMark(name: "step", series: "key-drag", time: ProcessInfo.processInfo.systemUptime))
    }

    /// Escape while the drag runs sends its steps back and ends it; the event stops here.
    private func watchEscape() {
        let box = press
        let actions = actions
        let pill = $pillFrame
        box.stopWatchingEscape()
        box.cancel = {
            guard var drag = box.drag, !drag.ended else { return false }
            drag.cancel(actions: actions)
            box.drag = drag
            pill.wrappedValue = nil
            return true
        }
        box.escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == TimelineLanePressBox.escapeKeyCode else { return event }
            let handled = MainActor.assumeIsolated { box.cancel?() ?? false }
            return handled ? nil : event
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
    /// How near a clip's start or end tick a press must land to trim it.
    static let clipEndReach: Double = 6

    /// The clip end within 6 pt of `x` (the nearest, when two are), or nil.
    /// Keys come first: the caller asks only when no key is hit.
    static func clipEnd<ID>(atX x: CGFloat, on track: TimelineTrack<ID>, mapping: FrameMapping) -> TimelineClipEnd? {
        let local = Double(x) - Double(timelineInset)
        var best: (end: TimelineClipEnd, distance: Double)?
        for span in track.spans {
            let lo = mapping.x(forFrame: span.lowerBound)
            let toStart = abs(local - lo)
            let toEnd = abs(local - mapping.x(forFrame: span.upperBound))
            // A tie (a one-tick clip, or its middle) goes to the end on or right of the start.
            let edge: SpanEdge = toEnd < toStart || (toEnd == toStart && local >= lo) ? .end : .start
            let distance = min(toStart, toEnd)
            guard distance <= clipEndReach, best.map({ distance < $0.distance }) ?? true else { continue }
            best = (TimelineClipEnd(span: span, edge: edge), distance)
        }
        return best?.end
    }

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
    var onMoveKeyframes: @MainActor (Int) -> Void = { _ in }
    var onEndKeyDrag: @MainActor () -> Void = {}
    var onTrim: @MainActor (ID, SpanEdge, Int) -> Void = { _, _, _ in }
    var onEndTrim: @MainActor () -> Void = {}
}

/// One end of one of a lane's clips.
struct TimelineClipEnd: Equatable, Sendable {
    let span: ClosedRange<Int>
    let edge: SpanEdge
}

/// A lane's press in progress, kept where SwiftUI doesn't watch it.
@MainActor final class TimelineLanePressBox {
    /// AppKit's key code for Escape.
    nonisolated static let escapeKeyCode: UInt16 = 53
    var active = false
    var target: TimelineLanePress.Target = .bed
    var modifiers: KeyModifiers = []
    var drag: TimelineKeyDrag?
    var trim: TimelineTrimDrag?
    var escapeMonitor: Any?
    /// Escape's cancel for the drag under way; true when it cancelled one.
    var cancel: (@MainActor () -> Bool)?

    func reset() {
        active = false
        drag = nil
        trim = nil
        stopWatchingEscape()
    }

    func stopWatchingEscape() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        cancel = nil
    }
}

/// A key drag on one lane, with no view (TL-14): the grabbed key's frame
/// follows the pointer, snapped to the playhead (TL-13), and the picked group
/// moves with it, clamped as a group (TL-10). The host hears only frame steps.
struct TimelineKeyDrag: Equatable, Sendable {
    /// The grabbed key's frame when the press began.
    let grabbed: Int
    /// The lane's keys that move, as their frames when the press began.
    let group: Set<Int>
    let playhead: Int
    let mapping: FrameMapping
    /// The grabbed key was picked at the press, so its pick waits for a click's release.
    let pickWaits: Bool
    private(set) var steps = TimelineDragSteps()
    /// A step went to the host, so the release ends a drag, not a click.
    private(set) var moved = false
    /// Released or cancelled: nothing more is sent.
    private(set) var ended = false

    /// `replacing` drops the old pick (a plain press on an unpicked key), so only the grabbed key moves.
    init(grabbing frame: Int, picked: Set<Int>, replacing: Bool, playhead: Int, mapping: FrameMapping) {
        grabbed = frame
        group = replacing ? [frame] : picked.union([frame])
        pickWaits = picked.contains(frame)
        self.playhead = playhead
        self.mapping = mapping
    }

    /// The grabbed key's frame now.
    var frame: Int { grabbed + steps.lastSent }

    /// Frames the group moves for a pointer `dx` points from the press:
    /// snapped(grabbed + frameDelta(dx)) - grabbed, clamped as a group.
    func total(dx: Double) -> Int {
        let scale = TimelineScale(lastFrame: mapping.duration, frameWidth: mapping.frameWidth)
        let keys = SuiteKeyEditing()
        let target = SuiteTimelineEditing().snapped(
            grabbed + keys.frameDelta(points: dx, scale: scale), playhead: playhead,
            radius: Double(SuiteSize.timelineKeyframeHit / 2), scale: scale)
        let lane = Set(group.map { LaneKey(track: "", frame: $0) })
        let moved = keys.moved(lane, by: target - grabbed, lastFrame: mapping.duration)
        return moved[LaneKey(track: "", frame: grabbed)].map { $0 - grabbed } ?? 0
    }

    /// Sends the frames moved since the last send; true when it sent a step.
    @MainActor mutating func move<ID>(dx: Double, actions: TimelineLaneActions<ID>) -> Bool {
        guard !ended, let delta = steps.step(toTotal: total(dx: dx)) else { return false }
        moved = true
        actions.onMoveKeyframes(delta)
        return true
    }

    /// Escape: sends back every frame sent, then ends the drag.
    @MainActor mutating func cancel<ID>(actions: TimelineLaneActions<ID>) {
        guard !ended else { return }
        ended = true
        guard moved else { return }
        if let back = steps.step(toTotal: 0) { actions.onMoveKeyframes(back) }
        actions.onEndKeyDrag()
    }

    /// The release: ends a drag that moved, once. True when nothing moved or
    /// was cancelled on a key picked at the press, so its waiting pick runs.
    @MainActor mutating func release<ID>(actions: TimelineLaneActions<ID>) -> Bool {
        guard !ended else { return false }
        ended = true
        guard moved else { return pickWaits }
        actions.onEndKeyDrag()
        return false
    }

    /// The release at pointer `dx`: the release's own sample can move further
    /// than the last change did, so that step goes first, then the release (#1796).
    @MainActor mutating func release<ID>(atDX dx: Double, actions: TimelineLaneActions<ID>) -> Bool {
        _ = move(dx: dx, actions: actions)
        return release(actions: actions)
    }
}

/// A clip-end trim on one lane, with no view (TL-15): the grabbed edge follows
/// the pointer, snapped to the playhead (TL-13) and kept by the trim rule
/// (inside 0...lastFrame, at least a frame long, the other edge fixed). The
/// host hears the edge's frame only when it changes, and one end.
struct TimelineTrimDrag: Equatable, Sendable {
    let end: TimelineClipEnd
    let playhead: Int
    let mapping: FrameMapping
    /// The grabbed edge's frame now (what the host was last sent).
    private(set) var frame: Int
    /// A trim went to the host, so the release ends a trim, not a click.
    private(set) var moved = false
    /// Released: nothing more is sent.
    private(set) var ended = false

    init(_ end: TimelineClipEnd, playhead: Int, mapping: FrameMapping) {
        self.end = end
        self.playhead = playhead
        self.mapping = mapping
        frame = end.edge == .start ? end.span.lowerBound : end.span.upperBound
    }

    /// The edge's frame for a pointer `dx` points from the press:
    /// trimmed(span, edge, snapped(frame(atX: edge x + dx))).
    func edgeFrame(dx: Double) -> Int {
        let grabbed = end.edge == .start ? end.span.lowerBound : end.span.upperBound
        let raw = mapping.frame(atX: mapping.x(forFrame: grabbed) + dx)
        let scale = TimelineScale(lastFrame: mapping.duration, frameWidth: mapping.frameWidth)
        let edits = SuiteTimelineEditing()
        let target = edits.snapped(raw, playhead: playhead, radius: Double(SuiteSize.timelineKeyframeHit / 2), scale: scale)
        let span = edits.trimmed(end.span, edge: end.edge, to: target, lastFrame: mapping.duration)
        return end.edge == .start ? span.lowerBound : span.upperBound
    }

    /// Sends the edge's frame when it changed; true when it sent one.
    @MainActor mutating func move<ID>(dx: Double, id: ID, actions: TimelineLaneActions<ID>) -> Bool {
        let new = edgeFrame(dx: dx)
        guard !ended, new != frame else { return false }
        frame = new
        moved = true
        actions.onTrim(id, end.edge, new)
        return true
    }

    /// The release: ends a trim that moved, once. True when nothing moved, so it acts as a click.
    @MainActor mutating func release<ID>(actions: TimelineLaneActions<ID>) -> Bool {
        guard !ended else { return false }
        ended = true
        guard moved else { return true }
        actions.onEndTrim()
        return false
    }

    /// The release at pointer `dx`: the edge takes the release's sample first, then the trim ends (#1796).
    @MainActor mutating func release<ID>(atDX dx: Double, id: ID, actions: TimelineLaneActions<ID>) -> Bool {
        _ = move(dx: dx, id: id, actions: actions)
        return release(actions: actions)
    }
}

/// What a press on a lane does, with no view (TL-11; B5, B6).
@MainActor enum TimelineLanePress {
    /// Where a press lands: on a key's frame, a clip's end, or the bed.
    enum Target: Equatable, Sendable {
        case key(Int)
        case clipEnd(TimelineClipEnd)
        case bed
    }

    /// The key within half the 16 pt token of lane x `x`, else a clip end
    /// within 6 pt (TL-15), else the bed.
    static func target<ID>(atX x: CGFloat, on track: TimelineTrack<ID>, mapping: FrameMapping) -> Target {
        if let key = TimelineLaneHit.key(atX: x, on: track, mapping: mapping) { return .key(key) }
        return TimelineLaneHit.clipEnd(atX: x, on: track, mapping: mapping).map { .clipEnd($0) } ?? .bed
    }

    /// A left press: a key is picked by the pick rule (a plain press also
    /// selects it); the bed, or a clip end that didn't move, selects the
    /// track and clears the pick (B5).
    static func press<ID>(
        _ target: Target, modifiers: KeyModifiers, on track: TimelineTrack<ID>, actions: TimelineLaneActions<ID>
    ) {
        switch target {
        case .key(let frame):
            actions.onPickKeyframe(track.id, frame, TimelinePick.mode(pressWith: modifiers))
            if modifiers.isEmpty { actions.onSelectKeyframe(track.id, frame) }
        case .bed, .clipEnd:
            actions.onSelectTrack(track.id)
            actions.onPickKeyframe(track.id, nil, .replace)
        }
    }

    /// A press begins: on a key it starts a drag, and an unpicked key is
    /// picked at once (the pick rule, so a plain press replaces the pick) so
    /// the drag moves it; a picked key's pick waits for a click's release.
    /// The bed starts nothing and acts on release.
    static func begin<ID>(
        _ target: Target, modifiers held: KeyModifiers, on track: TimelineTrack<ID>, playhead: Int,
        mapping: FrameMapping, actions: TimelineLaneActions<ID>
    ) -> TimelineKeyDrag? {
        guard case .key(let frame) = target else { return nil }
        let picked = track.pickedFrames.contains(frame)
        if !picked { press(target, modifiers: held, on: track, actions: actions) }
        let replacing = !picked && TimelinePick.mode(pressWith: held) == .replace
        return TimelineKeyDrag(
            grabbing: frame, picked: track.pickedFrames, replacing: replacing, playhead: playhead, mapping: mapping)
    }

    /// A press on a clip end starts a trim; anything else starts none.
    static func beginTrim(_ target: Target, playhead: Int, mapping: FrameMapping) -> TimelineTrimDrag? {
        guard case .clipEnd(let end) = target else { return nil }
        return TimelineTrimDrag(end, playhead: playhead, mapping: mapping)
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
