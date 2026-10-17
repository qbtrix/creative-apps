// TimelineLanesView+Access.swift: TL-23, the AppKit lanes' VoiceOver tree.
// Each key a lane draws is an accessibility child of TimelineLanesView, a
// button over its 16 pt token, mirroring TimelineLaneAccess (TL-12): its label
// is TimelineLaneSpeech's key label, its value the lane's spoken value, it is
// selected while picked, and its default action is a plain click on the key
// through the view's pointer, which picks it alone (.replace). The strings and
// the visible-keys rule are TimelineLaneSpeech's; nothing here builds its own.
// The children are rebuilt only when the lanes or the visible stretch change,
// so VoiceOver keeps its place across a read. macOS only.
import AppKit

/// One key's accessibility child on the lanes view: its lane, its key child and where it sits.
struct TimelineLaneKeyAccess: Equatable, Sendable {
    let lane: Int
    let child: TimelineKeyChild
    /// The lane's spoken value (TimelineLaneSpeech.value).
    let value: String
    /// The key's 16 pt token in the view's flipped coordinates.
    let token: CGRect

    /// Where a click on the key lands.
    var center: CGPoint { CGPoint(x: token.midX, y: token.midY) }
}

/// The lanes view's key children, with no view (TimelineLanesAccessTests).
enum TimelineLanesAccess {
    /// Every lane's key children, lane by lane in frame order; with a visible
    /// x range (view x), only the keys TimelineLaneSpeech keeps for it.
    static func keys(
        of lanes: [TimelineLaneDrawing], width: CGFloat, visibleX: ClosedRange<CGFloat>? = nil
    ) -> [TimelineLaneKeyAccess] {
        let frames = TimelineLaneLayers.frames(count: lanes.count, width: width)
        let size = SuiteSize.timelineKeyframeHit
        // TimelineLaneSpeech reads mapping x, which starts timelineInset into the view.
        let shown = visibleX.map { Double($0.lowerBound - timelineInset)...Double($0.upperBound - timelineInset) }
        var keys: [TimelineLaneKeyAccess] = []
        for (index, (lane, frame)) in zip(lanes, frames).enumerated() {
            let track = track(of: lane, index: index)
            let value = TimelineLaneSpeech.value(of: track)
            for child in TimelineLaneSpeech.children(of: track, visibleX: shown, mapping: shown == nil ? nil : lane.mapping) {
                let token = CGRect(
                    x: tickX(lane.mapping, child.frame) - size / 2, y: frame.midY - size / 2, width: size, height: size)
                keys.append(TimelineLaneKeyAccess(lane: index, child: child, value: value, token: token))
            }
        }
        return keys
    }

    /// The drawn lane as a track, so TimelineLaneSpeech reads it as TimelineLaneAccess does.
    static func track(of lane: TimelineLaneDrawing, index: Int) -> TimelineTrack<Int> {
        TimelineTrack(
            id: index, name: "", keys: lane.keys, spans: lane.spans, pickedFrames: lane.pickedFrames,
            isSelected: lane.isSelected)
    }
}

/// A key's accessibility element: a button whose press clicks the key on its view.
final class TimelineLaneKeyElement: NSAccessibilityElement {
    let key: TimelineLaneKeyAccess
    private weak var view: TimelineLanesView?

    init(_ key: TimelineLaneKeyAccess, in view: TimelineLanesView) {
        self.key = key
        self.view = view
        super.init()
        setAccessibilityRole(.button)
        setAccessibilityLabel(key.child.label)
        setAccessibilityValue(key.value)
        setAccessibilitySelected(key.child.picked)
        setAccessibilityParent(view)
        setAccessibilityFrameInParentSpace(key.token)
    }

    override func accessibilityPerformPress() -> Bool {
        let (key, view) = (key, view)  // both Sendable, so the closure captures no element state
        return MainActor.assumeIsolated { view?.pickKey(key) ?? false }
    }
}

/// The children a lanes view last built, and what they were built from.
@MainActor private final class TimelineLanesAccessCache {
    var lanes: [TimelineLaneDrawing] = []
    var visibleX: ClosedRange<CGFloat>?
    var width: CGFloat = 0
    var elements: [TimelineLaneKeyElement] = []
}

/// Each lanes view's cache, dropped with its view.
@MainActor private let timelineLanesAccessCaches = NSMapTable<TimelineLanesView, TimelineLanesAccessCache>.weakToStrongObjects()

extension TimelineLanesView {
    override func isAccessibilityElement() -> Bool { true }

    override func accessibilityRole() -> NSAccessibility.Role? { .group }

    override func accessibilityChildren() -> [Any]? { keyElements() }

    /// The key children for the lanes shown, rebuilt only when the lanes, the width or the visible stretch change.
    func keyElements() -> [TimelineLaneKeyElement] {
        let visible = visibleRect
        let visibleX = visible.isEmpty ? nil : visible.minX...visible.maxX
        let cache = timelineLanesAccessCaches.object(forKey: self) ?? TimelineLanesAccessCache()
        timelineLanesAccessCaches.setObject(cache, forKey: self)
        if cache.lanes == lanes, cache.visibleX == visibleX, cache.width == bounds.width {
            return cache.elements
        }
        (cache.lanes, cache.visibleX, cache.width) = (lanes, visibleX, bounds.width)
        cache.elements = TimelineLanesAccess.keys(of: lanes, width: bounds.width, visibleX: visibleX)
            .map { TimelineLaneKeyElement($0, in: self) }
        return cache.elements
    }

    /// A key child's default action: a plain click on the key, which picks it alone; false with no pointer.
    @discardableResult func pickKey(_ key: TimelineLaneKeyAccess) -> Bool {
        guard pointer != nil else { return false }
        press(at: key.center, flags: [])
        release(at: key.center)
        return true
    }
}
