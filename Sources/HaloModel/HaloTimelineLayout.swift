// HaloTimelineLayout.swift: the timeline strip's geometry, in points. The
// lane width that fits every frame without the strip scrolling sideways (the
// name column, the divider and the strip's trailing room come off the
// width), and the timeline's height: its ruler and lanes, at least the slot
// minimum, at most a share of the height it sits in so the canvas keeps room
// (past that the lanes scroll), and which lane a click lands in. The view
// passes SuiteUI's tokens in; the Model can't see them. Linux-safe: no UI imports. Never negative.

/// The timeline strip's sizes, from the design tokens.
public struct HaloTimelineLayout: Sendable, Hashable {
    /// The fixed track-name column on the left.
    public var labelColumn: Double
    /// The line between the names and the lanes.
    public var divider: Double
    /// The room the strip adds after the last frame.
    public var trailingRoom: Double
    /// The frame ruler's height.
    public var ruler: Double
    /// One lane's height.
    public var lane: Double
    /// The least height the timeline takes when there is room for it.
    public var minimumHeight: Double
    /// The largest share of the available height the timeline takes.
    public var maximumShare: Double

    public init(
        labelColumn: Double, divider: Double, trailingRoom: Double, ruler: Double, lane: Double,
        minimumHeight: Double, maximumShare: Double = 0.4
    ) {
        self.labelColumn = labelColumn
        self.divider = divider
        self.trailingRoom = trailingRoom
        self.ruler = ruler
        self.lane = lane
        self.minimumHeight = minimumHeight
        self.maximumShare = maximumShare
    }

    /// The width to fit every frame into, for a strip `width` points wide, so
    /// the lanes plus their trailing room end exactly at the strip's edge.
    public func laneFitWidth(width: Double) -> Double {
        guard width.isFinite else { return 0 }
        return max(0, width - labelColumn - divider - trailingRoom)
    }

    /// The width to fit every frame into, from the width the strip was
    /// actually laid out at (`strip`, measured in the live window) or, before
    /// that is known, the container's `container` width. The measured width
    /// is the one that shows: a container width can count room under a
    /// floating sidebar or inspector, and lanes fitted to it run past the
    /// strip's edge and lose their last frames (#1019).
    public func laneFitWidth(strip: Double?, container: Double) -> Double {
        guard let strip, strip.isFinite, strip > 0 else { return laneFitWidth(width: container) }
        return laneFitWidth(width: strip)
    }

    /// The lane, top first, of a click at (`x`, `y`) in a strip of `rows`
    /// lanes; nil on the ruler, the name column or the divider, or below the
    /// last lane.
    public func row(atX x: Double, y: Double, rows: Int) -> Int? {
        guard x.isFinite, y.isFinite, x > labelColumn + divider, y >= ruler, y < ruler + lane * Double(max(rows, 0))
        else { return nil }
        return Int((y - ruler) / lane)
    }

    /// The ruler and one lane per row; an empty timeline keeps one lane's
    /// height for its hint.
    public func contentHeight(rows: Int) -> Double {
        max(0, ruler + lane * Double(max(1, rows)))
    }

    /// The timeline's height for `rows` lanes in `available` points: its
    /// content, at least `minimumHeight`, and never over `maximumShare` of
    /// `available`, which wins over the minimum when the two disagree.
    public func height(rows: Int, available: Double) -> Double {
        guard available.isFinite, available > 0 else { return 0 }
        let cap = available * min(max(maximumShare, 0), 1)
        return max(0, min(max(contentHeight(rows: rows), minimumHeight), cap))
    }
}
