// DesignFrameLabel.swift: where the canvas puts a frame's name (#1387). The
// name sits just above the frame's top-left corner when the artboard has room
// for it there; otherwise it sits just inside the frame's top, and never above
// the artboard's top edge, which clips the canvas. Plain numbers in one space
// (the view passes screen points: the frame's top after the zoom, the
// artboard's top and the name's measured height), so it runs on Linux.
// Linux-safe: no UI imports.

/// Where a frame's name goes on the canvas, and its top edge.
public enum DesignFrameLabel: Equatable, Sendable {
    /// Above the frame: the name's bottom edge sits `gap` above the frame's top.
    case above(bottom: Double)
    /// Inside the frame: the name's top edge sits `inset` below the frame's top, or
    /// below the artboard's top when the frame crosses it.
    case inside(top: Double)

    /// Places a name `labelHeight` tall for a frame whose top is `frameTop`, on an artboard whose
    /// top is `artboardTop`. Above when the gap and the whole name fit between the two tops.
    public static func place(
        frameTop: Double, artboardTop: Double, labelHeight: Double, gap: Double, inset: Double
    ) -> DesignFrameLabel {
        let room = frameTop - artboardTop
        if room.isFinite, room >= labelHeight + gap {
            return .above(bottom: frameTop - gap)
        }
        return .inside(top: Swift.max(frameTop, artboardTop) + inset)
    }

    /// Whether the name sits inside the frame, on its fill.
    public var isInside: Bool {
        if case .inside = self { return true }
        return false
    }
}
