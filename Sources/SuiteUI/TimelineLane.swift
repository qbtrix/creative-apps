// TimelineLane.swift: one track's lane in TimelineStrip (timeline packet,
// TL-6), drawn with TimelineLook's rules. A laneBed bed at radius `lane`
// with 2 pt above and below, under the selectedTint when the track is
// selected; clip blocks in clipFill from tick to tick, at least a key wide;
// a 2 pt textTertiary tween between consecutive keys (a step after a hold
// key, a curve glyph on a wide eased gap); keys over everything in their
// shape, fill and edge from their own pick, never the track's selection
// (#1423). Hover (from TimelineLaneInput, through the environment) turns the
// bed rowHover and rings the key under the pointer in a 2 pt accent ring
// 1 pt outside it, fading with SuiteMotion.state. Equatable over its values
// and holding no closure, so the strip's `.equatable()` skips a lane whose
// track and mapping didn't change, and a hover change redraws only its own
// lane. Accessibility is in TimelineLaneAccess; the geometry is
// TimelineLaneGeometry, with no view.
import SwiftUI

struct TimelineLane<ID: Hashable & Sendable>: View {
    let track: TimelineTrack<ID>
    let mapping: FrameMapping
    @Environment(\.timelineLaneHover) private var hover
    @Environment(\.suiteReduceMotion) private var reduceMotion

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
        let track = track
        let mapping = mapping
        let ringed = hover?.key
        return Canvas { context, size in
            let bedRect = TimelineLaneGeometry.bed(width: size.width, height: size.height)
            for span in track.spans {
                let block = TimelineLaneGeometry.block(span, mapping: mapping, bed: bedRect)
                let shape = Path(roundedRect: block, cornerRadius: TimelineLaneGeometry.radius(of: block))
                context.fill(shape, with: .color(TimelineLook.clipFill.color()))
            }
            drawKeys(of: track, mapping: mapping, ringed: ringed, mid: bedRect.midY, in: &context)
        }
        .frame(height: SuiteSize.timelineLane)
        // A view background, not a color one, so it keeps to the safe area (#1034).
        .background(alignment: .center) { bedLayer }
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: hover)
        .modifier(TimelineLaneAccess(track: track))
    }

    /// The bed: rowHover under the pointer, else laneBed, under the selectedTint on a selected track.
    private var bedLayer: some View {
        let bed = RoundedRectangle(cornerRadius: SuiteRadius.lane)
        return bed.fill(hover == nil ? SuiteColor.laneBed : SuiteColor.rowHover)
            .overlay { if track.isSelected { bed.fill(SuiteColor.selectedTint) } }
            .padding(.vertical, TimelineLaneGeometry.gap)
    }
}

/// The tweens, then the keys over them, then the hover ring.
private func drawKeys<ID>(
    of track: TimelineTrack<ID>, mapping: FrameMapping, ringed: Int?, mid: CGFloat, in context: inout GraphicsContext
) {
    let keys = track.keys.sorted { $0.frame < $1.frame }
    let tweenWidth = SuiteSpacing.xxs
    let glyph = SuiteSpacing.xs
    var tween = Path()
    for (a, b) in zip(keys, keys.dropFirst()) {
        let (ax, bx) = (tickX(mapping, a.frame), tickX(mapping, b.frame))
        let segment = TimelineLook.segment(from: a, at: Double(ax), to: b, at: Double(bx))
        switch segment.kind {
        case .line:
            tween.move(to: CGPoint(x: ax, y: mid))
            tween.addLine(to: CGPoint(x: bx, y: mid))
        case .step:
            tween.move(to: CGPoint(x: ax, y: mid + glyph))
            tween.addLine(to: CGPoint(x: bx, y: mid + glyph))
            tween.addLine(to: CGPoint(x: bx, y: mid))
        }
        if let x = segment.curveGlyphX.map({ CGFloat($0) }) {
            tween.move(to: CGPoint(x: x - glyph, y: mid + glyph))
            tween.addCurve(
                to: CGPoint(x: x + glyph, y: mid - glyph),
                control1: CGPoint(x: x, y: mid + glyph), control2: CGPoint(x: x, y: mid - glyph))
        }
    }
    context.stroke(tween, with: .color(SuiteColor.textTertiary), lineWidth: tweenWidth)
    let size = SuiteSize.timelineKeyframe
    for key in keys {
        let picked = track.pickedFrames.contains(key.frame)
        let center = CGPoint(x: tickX(mapping, key.frame), y: mid)
        let look = TimelineLook.keyPath(key.shape)
        let shape = TimelineLaneGeometry.keyShape(look.glyph, center: center, size: size)
        let edge = TimelineLook.keyEdge(picked: picked)
        context.fill(shape, with: .color(TimelineLook.keyFill(picked: picked, atPlayhead: false).color()))
        context.stroke(shape, with: .color(edge.color.color()), lineWidth: CGFloat(edge.width))
        if key.frame == ringed {
            // The ring's centre line sits its half width beyond a 1 pt gap.
            let out = SuiteSize.focusRingGap + SuiteSize.focusRing / 2
            let ring = TimelineLaneGeometry.keyShape(look.glyph, center: center, size: size + out * 2)
            context.stroke(ring, with: .color(SuiteColor.accent), lineWidth: SuiteSize.focusRing)
        }
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
