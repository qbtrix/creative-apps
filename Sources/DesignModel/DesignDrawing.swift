// DesignDrawing.swift: the Frame, Rectangle, Ellipse and Text tools' gestures.
// A drawing tool adds its node, selected, on the gesture's first move and
// reshapes it on each later one (rewinding to the document at the start, so the
// node keeps its id). The node goes inside the deepest visible, unlocked frame
// under the start, or at the top of the page when no frame is there.
//
//   frame, rectangle, ellipse  the rectangle from the start to the pointer
//                              (Shift: a square growing away from the start),
//                              both sides at least 1, both ends on whole points
//                              (DesignWholePoints). A gesture that never left
//                              its start is the kind's default size there.
//   text                       a click: a "Text" node of the default size at the
//                              start, auto width. A drag (canvas-basics CB-3): a
//                              box from the start to the pointer on whole points,
//                              at least 8 wide and the default height tall, with
//                              a fixed width. endDrag starts its inline edit
//                              (DesignText).
// Linux-safe.

extension DesignWorkspace {
    /// The gesture's drawing step: the node of `kind` as of the pointer at `end`.
    mutating func draw(_ kind: DesignNodeKind, from gesture: DesignGesture, to end: DesignPoint, square: Bool) {
        let start = gesture.start.wholePoints
        var frame = defaultFrame(kind, at: start)
        if gesture.moved {
            frame = DesignRect(from: start, to: end.wholePoints, square: square)
            (frame.width, frame.height) = (Swift.max(frame.width, 1), Swift.max(frame.height, 1))
        }
        rewind(to: gesture.before)
        place(kind, frame: frame, at: gesture.start)
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
