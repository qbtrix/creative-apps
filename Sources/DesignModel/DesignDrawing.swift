// DesignDrawing.swift: the Frame, Rectangle, Ellipse, Shape and Text tools' gestures.
// A drawing tool adds its node, selected, on the gesture's first move and
// reshapes it on each later one (rewinding to the document at the start, so the
// node keeps its id). The node goes inside the deepest visible, unlocked frame
// under the start, or at the top of the page when no frame is there.
//
//   frame, rectangle, ellipse, shape   the box the kernel's `ShapeRules.dragged`
//                              gives for the drag between the start and the
//                              pointer, both on whole points (DesignWholePoints):
//                              Shift squares it (a line snaps to 45°), Option grows
//                              it from the start as its centre. Both sides at least
//                              1. A gesture that never left its start is the kind's
//                              default size there. Shape draws the tool's spec
//                              (`shapeTool`, a line's ends from the drag) through
//                              `addShape`, each sample rewinding the history too, so
//                              the gesture is one step "Draw <Kind>" (shape-tools DS-5).
//   text                       a click: a "Text" node of the default size at the
//                              start, auto width. A drag (canvas-basics CB-3): a
//                              box from the start to the pointer on whole points,
//                              at least 8 wide and the default height tall, with
//                              a fixed width. endDrag starts its inline edit
//                              (DesignText).
// Linux-safe.
import SuiteKernel

extension DesignWorkspace {
    /// The gesture's drawing step: the node of `kind` as of the pointer at `end`.
    mutating func draw(_ kind: DesignNodeKind, from gesture: DesignGesture, to end: DesignPoint, modifiers: DesignModifiers) {
        let frame = dragged(kind == .ellipse ? .ellipse : .rectangle, kind, from: gesture, to: end, modifiers: modifiers).frame
        rewind(to: gesture.before)
        place(kind, frame: frame, at: gesture.start)
    }

    /// The Shape tool's step: the tool's spec in the dragged box, a line or arrow taking its ends from the
    /// drag, added through `addShape` after rewinding the document and its history to the start.
    mutating func drawShape(from gesture: DesignGesture, to end: DesignPoint, modifiers: DesignModifiers) {
        var spec = shapeTool
        let drawn = dragged(spec.kind, .shape, from: gesture, to: end, modifiers: modifiers)
        if spec.kind == .line || spec.kind == .arrow { (spec.start, spec.end) = (drawn.spec.start, drawn.spec.end) }
        rewind(to: gesture.before)
        history = gesture.history
        _ = try? addShape(spec, frame: drawn.frame, at: gesture.start, name: "Draw \(spec.kind.rawValue.capitalized)")
    }

    /// The box `ShapeRules.dragged` gives a drag of `shape` from the gesture's start to `end` on whole
    /// points, each side at least 1 (a drag back to its start: 1 by 1 there), with the spec it carries; `kind`'s
    /// default box at the start for a click.
    private func dragged(
        _ shape: ShapeKind, _ kind: DesignNodeKind, from gesture: DesignGesture, to end: DesignPoint, modifiers: DesignModifiers
    ) -> (frame: DesignRect, spec: ShapeSpec) {
        let (start, end) = (gesture.start.wholePoints, end.wholePoints)
        guard gesture.moved else { return (defaultFrame(kind, at: start), .defaults(shape)) }
        let drawn = ShapeRules.dragged(
            shape, from: Point(x: start.x, y: start.y), to: Point(x: end.x, y: end.y), modifiers: modifiers.editModifiers)
        var frame = drawn.map { DesignRect($0.box) } ?? DesignRect(x: start.x, y: start.y, width: 0, height: 0)
        (frame.width, frame.height) = (Swift.max(frame.width, 1), Swift.max(frame.height, 1))
        return (frame, drawn?.spec ?? .defaults(shape))
    }

    /// The Text tool's step: a click places a default-size, auto-width text node at the
    /// gesture's start; a drag a fixed-width box from the start to `end`.
    mutating func placeText(from gesture: DesignGesture, to end: DesignPoint) {
        rewind(to: gesture.before)
        guard gesture.moved else {
            place(.text, frame: defaultFrame(.text, at: gesture.start), at: gesture.start)
            return
        }
        var frame = DesignRect(from: gesture.start, to: end).wholePoints
        frame.width = Swift.max(frame.width, Self.minimumTextWidth)
        frame.height = Swift.max(frame.height, DesignNodeKind.text.defaultSize.height)
        guard let id = place(.text, frame: frame, at: gesture.start) else { return }
        _ = pages.update(id) { $0.textStyle.fixedWidth = true }
    }

    /// The narrowest box a Text drag makes.
    static let minimumTextWidth = 8.0

    private func defaultFrame(_ kind: DesignNodeKind, at point: DesignPoint) -> DesignRect {
        DesignRect(x: point.x, y: point.y, width: kind.defaultSize.width, height: kind.defaultSize.height)
    }

    @discardableResult
    private mutating func place(_ kind: DesignNodeKind, frame: DesignRect, at point: DesignPoint) -> String? {
        let parent = selectedPage?.nodes.deepestFrame(containing: point)
        // The page is selected and the parent was just found on it, so the add cannot be refused.
        return try? insertNode(kind, frame: frame, in: parent)
    }
}
