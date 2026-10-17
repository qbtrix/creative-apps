// TimelineLane.swift: one track's lane in TimelineStrip (timeline packet,
// TL-6), drawn with TimelineLook's rules. A laneBed bed at radius `lane`
// with 2 pt above and below, under the selectedTint when the track is
// selected; clip blocks in clipFill from tick to tick, at least a key wide;
// a 2 pt textTertiary tween between consecutive keys (a step after a hold
// key, a curve glyph on a wide eased gap); keys over everything in their
// shape, fill and edge from their own pick, never the track's selection
// (#1423). Hover (from TimelineLaneInput, through the environment) turns the
// bed rowHover and rings the key under the pointer in a 2 pt accent ring
// 1 pt outside it, drawn by TimelineLanes' layer (TL-21). Equatable over its values
// and holding no closure, so the strip's `.equatable()` skips a lane whose
// track and mapping didn't change, and a hover change redraws only its own
// lane. Accessibility is in TimelineLaneAccess; the geometry is
// TimelineLaneGeometry, with no view.
import SwiftUI

struct TimelineLane<ID: Hashable & Sendable>: View {
    let track: TimelineTrack<ID>
    let mapping: FrameMapping
    @Environment(\.timelineLaneHover) private var hover

    #if DEBUG
    /// How many times a lane's body ran, over every ID type; the real-window
    /// budget tests count a scrub's.
    static var bodyRuns: Int {
        get { timelineLaneBodyRuns }
        set { timelineLaneBodyRuns = newValue }
    }
    #endif

    var body: some View {
        #if DEBUG
        Self.bodyRuns += 1
        #endif
        return TimelineLanes(lanes: [TimelineLaneDrawing(track, mapping: mapping, hover: hover)])
            .frame(height: SuiteSize.timelineLane)
            .modifier(TimelineLaneAccess(track: track))
    }
}

/// A lane's geometry, with no view (TimelineLaneTests).
enum TimelineLaneGeometry {
    /// The room above and below the bed.
    static let gap = SuiteSpacing.xxs

    /// The bed in a lane `width` by `height`: the full width, `gap` in from top and bottom.
    static func bed(width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: 0, y: gap, width: max(width, 0), height: max(height - gap * 2, 0))
    }

    /// The block of `span`: from its first frame's tick to its last's, at
    /// least a key wide, 4 pt shorter than `bed` and centred in it.
    static func block(_ span: ClosedRange<Int>, mapping: FrameMapping, bed: CGRect) -> CGRect {
        let start = tickX(mapping, span.lowerBound)
        let width = max(tickX(mapping, span.upperBound) - start, SuiteSize.timelineKeyframe)
        let height = max(bed.height - SuiteSpacing.xs, 0)
        return CGRect(x: start, y: bed.midY - height / 2, width: width, height: height)
    }

    /// A block's corner radius: the lane's, at most half its height.
    static func radius(of block: CGRect) -> CGFloat {
        min(SuiteRadius.lane, block.height / 2)
    }

    /// A key's glyph `size` across, centred on `center`.
    static func keyShape(_ glyph: TimelineLook.KeyGlyph, center: CGPoint, size: CGFloat) -> Path {
        let half = size / 2
        let rect = CGRect(x: center.x - half, y: center.y - half, width: size, height: size)
        switch glyph {
        case .circle:
            return Path(ellipseIn: rect)
        case .square:
            return Path(rect)
        case .diamond:
            var path = Path()
            path.move(to: CGPoint(x: center.x, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: center.y))
            path.closeSubpath()
            return path
        }
    }
}

extension TimelineLane: Equatable {
    /// Compares the values a lane draws; its hover arrives through the environment.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track == rhs.track && lhs.mapping == rhs.mapping
    }
}

#if DEBUG
/// TimelineLane.bodyRuns' count: a generic type can't hold a static stored property.
@MainActor private var timelineLaneBodyRuns = 0
#endif
