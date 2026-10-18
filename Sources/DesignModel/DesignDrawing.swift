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
//   text                       a "Text" node of the default size at the start;
//                              endDrag starts its inline edit (DesignText).
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

    /// The Text tool's step: a default-size text node at the gesture's start.
    mutating func placeText(from gesture: DesignGesture) {
        rewind(to: gesture.before)
        place(.text, frame: defaultFrame(.text, at: gesture.start), at: gesture.start)
    }

    private func defaultFrame(_ kind: DesignNodeKind, at point: DesignPoint) -> DesignRect {
        DesignRect(x: point.x, y: point.y, width: kind.defaultSize.width, height: kind.defaultSize.height)
    }

    private mutating func place(_ kind: DesignNodeKind, frame: DesignRect, at point: DesignPoint) {
        let parent = selectedPage?.nodes.deepestFrame(containing: point)
        // The page is selected and the parent was just found on it, so the add cannot be refused.
        _ = try? insertNode(kind, frame: frame, in: parent)
    }
}
