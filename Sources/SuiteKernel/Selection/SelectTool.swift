// SelectTool.swift: the one Select tool rule every canvas app shares (#6012). A click picks what is under the
// pointer and moves nothing: alone it replaces the selection, with Shift it toggles the hit in or out, on empty
// canvas it clears (Shift on empty canvas keeps it). A drag on empty canvas draws a box whose touched items
// replace the selection, or with Shift join it (`Marquee.union`). An app supplies only a `SelectTarget` adapter
// (`<X>Select+Kernel.swift`): its point hit, its rect hit and the selection it keeps. A selection change is view
// state, never an undo step. SuiteUI's `SelectGesture` holds the press and the box while the pointer is down and
// calls `click` or `box` once, at the release, so a sample changes no model state. Linux-safe.

/// A canvas the Select tool picks on: an app's workspace conforms in its `<X>Select+Kernel.swift`.
public protocol SelectTarget: Sendable {
    /// The id of one selectable thing (a layer, a node, a stage item).
    associatedtype SelectID: Hashable & Sendable
    /// The topmost selectable thing under `point` in document space; nil on empty canvas.
    func layerHit(at point: Point) -> SelectID?
    /// The selectable things `rect` (document space) touches, in the app's order.
    func layerHits(in rect: Rect) -> [SelectID]
    /// The selection the app's layer list shows.
    var selectPicks: Selection<SelectID> { get }
    /// Makes `picks` the selection; the layer list follows it. View state, not an undo step.
    mutating func setSelectPicks(_ picks: Selection<SelectID>)
}

/// The Select tool's click and box rules.
public enum SelectTool {
    /// The selection after a click on `hit` (nil: empty canvas), with Shift held when `extending`.
    public static func click<ID>(_ selection: Selection<ID>, hit: ID?, extending: Bool) -> Selection<ID> {
        var next = selection
        switch (hit, extending) {
        case (let id?, false): next.pick(id, .replace)
        case (let id?, true): next.pick(id, .toggle)
        case (nil, false): next.clear()
        case (nil, true): break
        }
        return next
    }

    /// The selection after a box found `found`: they replace it, or with Shift (`extending`) join after it.
    public static func box<ID>(_ selection: Selection<ID>, found: [ID], extending: Bool) -> Selection<ID> {
        var next = selection
        next.replace(Marquee.union(selection.ordered, found, extending: extending))
        return next
    }

    /// The least drag, in document units, that makes a press a box instead of a click.
    public static let boxThreshold = 2.0

    /// Whether a press at `start` released at `end` is a box drag rather than a click.
    public static func isBox(from start: Point, to end: Point, threshold: Double = boxThreshold) -> Bool {
        abs(end.x - start.x) >= threshold || abs(end.y - start.y) >= threshold
    }

    /// The whole Select gesture on `target`, run once at the release: a click at `start` when the pointer barely
    /// moved, otherwise the box from `start` to `end`. Returns whether the selection changed.
    @discardableResult
    public static func release<T: SelectTarget>(_ target: inout T, from start: Point, to end: Point, extending: Bool) -> Bool {
        let before = target.selectPicks
        let next = isBox(from: start, to: end)
            ? box(before, found: target.layerHits(in: Marquee.rect(enclosing: start, end)), extending: extending)
            : click(before, hit: target.layerHit(at: start), extending: extending)
        guard next != before else { return false }
        target.setSelectPicks(next)
        return true
    }
}
