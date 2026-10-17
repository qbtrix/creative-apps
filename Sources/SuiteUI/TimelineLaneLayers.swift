// TimelineLaneLayers.swift: the rules of the AppKit lanes renderer, with no
// view (timeline packet, TL-20; slice TL-f, the dual-renderer amendment).
// TL-21's TimelineLanesView keeps one CALayer per lane and asks which lanes to
// redraw when its lane models change (`dirty`: an Equatable diff by index) and
// where each layer sits (`frames`: tiles at the strip's lane pitch, top down).
// TL-22's pointer input asks `route` what a press lands on: the playhead band
// first, as the strip's playhead layer sits over the lanes and takes the press
// today (TimelinePlayheadGrab.band, strictly inside its edge), else the lane's
// own classification from TimelineLanePress.target (key, clip end, bed), which
// TimelineLaneInput owns and this file never copies. Point x is the lanes' x,
// past timelineInset; y runs down from the lane area's top, as a flipped NSView
// has it. Foundation and CoreGraphics types only. TimelineLaneLayersTests.
import Foundation

enum TimelineLaneLayers {
    /// What a press on the lane area lands on.
    enum Press: Equatable, Sendable {
        case key(Int)
        case clipEnd(TimelineClipEnd)
        case playheadBand
        case bed

        /// The lane's own classification, as a press here.
        @MainActor init(_ target: TimelineLanePress.Target) {
            switch target {
            case .key(let frame): self = .key(frame)
            case .clipEnd(let end): self = .clipEnd(end)
            case .bed: self = .bed
            }
        }
    }

    /// A press routed: the lane it is on and what it landed on there.
    struct Route: Equatable, Sendable {
        let lane: Int
        let press: Press
    }

    /// The lanes whose layer redraws when `old` becomes `new`: each index of
    /// `new` whose lane differs from `old`'s there, or that `old` didn't
    /// have. A lane `old` had past `new`'s end has no layer to redraw.
    static func dirty<Lane: Equatable>(old: [Lane], new: [Lane]) -> Set<Int> {
        var dirty = Set<Int>()
        for (index, lane) in new.enumerated() where index >= old.count || old[index] != lane {
            dirty.insert(index)
        }
        return dirty
    }

    /// One layer frame per lane, `width` wide and `laneHeight` tall, tiled
    /// from y 0 down at a pitch of `laneHeight` plus `spacing` (the strip
    /// stacks lanes with none), so they neither gap nor overlap. A count
    /// below 0 is no lanes; a size below 0 or not finite is 0.
    static func frames(
        count: Int, laneHeight: CGFloat = SuiteSize.timelineLane, spacing: CGFloat = 0, width: CGFloat
    ) -> [CGRect] {
        let height = finite(laneHeight)
        let pitch = height + finite(spacing)
        let wide = finite(width)
        return (0..<max(count, 0)).map { CGRect(x: 0, y: CGFloat($0) * pitch, width: wide, height: height) }
    }

    /// The lane whose frame holds `y`: nil above the first, past the last of `count`, or in a spacing gap.
    static func lane(atY y: CGFloat, count: Int, laneHeight: CGFloat = SuiteSize.timelineLane, spacing: CGFloat = 0) -> Int? {
        let height = finite(laneHeight)
        let pitch = height + finite(spacing)
        guard count > 0, pitch > 0, y.isFinite, y >= 0 else { return nil }
        let slot = (y / pitch).rounded(.down)
        guard slot < CGFloat(count) else { return nil }  // compared before Int: a far y never reaches it
        let index = Int(slot)
        return y - CGFloat(index) * pitch < height ? index : nil
    }

    /// The playhead's band holds `x` when it lies strictly inside half the
    /// 16 pt token either side of the line at `playhead`'s tick.
    static func onPlayheadBand(x: CGFloat, playhead: Int, mapping: FrameMapping) -> Bool {
        let lineX = tickX(mapping, playhead)
        return abs(x - lineX) < TimelinePlayheadGrab.band / 2
    }

    /// What a press at `point` on `lanes` lands on: nil off every lane; the
    /// playhead band when the point is inside it; else the lane's own
    /// classification (TimelineLanePress.target: key, clip end, bed).
    @MainActor static func route<ID>(
        press point: CGPoint, in lanes: [TimelineTrack<ID>], mapping: FrameMapping, playhead: Int,
        laneHeight: CGFloat = SuiteSize.timelineLane, spacing: CGFloat = 0
    ) -> Route? {
        guard point.x.isFinite,
              let index = lane(atY: point.y, count: lanes.count, laneHeight: laneHeight, spacing: spacing),
              lanes.indices.contains(index)
        else { return nil }
        if onPlayheadBand(x: point.x, playhead: playhead, mapping: mapping) {
            return Route(lane: index, press: .playheadBand)
        }
        let target = TimelineLanePress.target(atX: point.x, on: lanes[index], mapping: mapping)
        return Route(lane: index, press: Press(target))
    }

    /// `value` when it is finite and at least 0, else 0.
    private static func finite(_ value: CGFloat) -> CGFloat { value.isFinite ? max(value, 0) : 0 }
}
