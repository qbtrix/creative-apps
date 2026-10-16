// TimelineLook.swift: the timeline strip's look rules, with no SwiftUI. It
// answers with SuitePalette entries (SuiteHex) and rects, so a lane, the
// playhead and later a CoreGraphics lane layer draw the same thing and the
// rules are unit-tested on their own (TL-5 of the timeline packet).
// - A key's fill follows only its own state: at the playhead it is keyed, picked
//   it is the accent, otherwise secondary text. It never reads the track's
//   selection, which turned every diamond accent with nothing picked (#1423).
// - A key's 1 pt edge carries its contrast on a clip (#62): panel when idle,
//   white when picked in the dark appearances. White on a light clip measures
//   1.46:1, so in Light the picked edge is the primary text ink.
// - A key's glyph follows its easing: linear a diamond, eased a circle, hold a
//   square; 10 pt drawn, 16 pt to hit (B11).
// - A clip block is the accent 24 % into the panel, written out per appearance.
// - Between two keys: a step after a hold key, else a line; an eased key adds
//   a curve glyph at the middle when the keys are 24 pt apart or more.
// - The time pill is centred on the playhead and clamped inside the visible
//   stretch of the lanes, so it never leaves them at frame 0 or the last frame.
import Foundation

public enum TimelineLook {
    /// A 1 pt key edge in a palette color.
    public struct Edge: Hashable, Sendable {
        public let color: SuiteHex
        public let width: Double
    }

    /// The glyph a key draws.
    public enum KeyGlyph: Hashable, Sendable { case diamond, circle, square }

    /// A key's glyph and its drawn and hit sizes, in points.
    public struct KeyPath: Hashable, Sendable {
        public let glyph: KeyGlyph
        public let drawSize: Double
        public let hitSize: Double

        /// The drawn square around a key's tick at `center`.
        public func drawRect(center: CGPoint) -> CGRect { square(center, drawSize) }
        /// The square a press must land in to hit the key.
        public func hitRect(center: CGPoint) -> CGRect { square(center, hitSize) }

        private func square(_ center: CGPoint, _ side: Double) -> CGRect {
            CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        }
    }

    /// What joins two consecutive keys.
    public struct Segment: Hashable, Sendable {
        public enum Kind: Hashable, Sendable { case line, step }
        public let kind: Kind
        /// The x of the eased curve glyph, nil when there is none.
        public let curveGlyphX: Double?
    }

    /// The accent 24 % into the panel, per appearance (Dark, Light, Dark +
    /// Increase Contrast, Light + Increase Contrast).
    public static let clipFill = SuiteHex(0x233A5B, 0xC1D8F6, 0x2A3D57, 0xC4D9F4)
    /// A picked key's edge: white in the dark appearances, the primary text ink in the light ones.
    public static let pickedEdge = SuiteHex(0xFFFFFF, 0x1D1D1F, 0xFFFFFF, 0x000000)
    /// The width of a key's edge.
    public static let edgeWidth = 1.0
    /// The narrowest gap between two keys that shows the eased curve glyph.
    public static let curveGlyphGap = 24.0
    /// The room the time pill keeps from either end of the visible stretch.
    public static let pillInset = Double(SuiteSpacing.xxs)

    /// The fill of `key` on `track` with the playhead at `playhead`.
    public static func keyFill<ID: Hashable & Sendable>(_ key: TimelineKey, on track: TimelineTrack<ID>, playhead: Int) -> SuiteHex {
        keyFill(picked: track.pickedFrames.contains(key.frame), atPlayhead: key.frame == playhead)
    }

    /// The fill of a key that is `picked` or `atPlayhead`.
    public static func keyFill(picked: Bool, atPlayhead: Bool) -> SuiteHex {
        atPlayhead ? SuitePalette.stateKeyed : picked ? SuitePalette.accent : SuitePalette.textSecondary
    }

    /// The edge of a key that is `picked` or not.
    public static func keyEdge(picked: Bool) -> Edge {
        Edge(color: picked ? pickedEdge : SuitePalette.panel, width: edgeWidth)
    }

    /// The glyph of a key of `shape`, 10 pt drawn and 16 pt to hit.
    public static func keyPath(_ shape: TimelineKeyShape) -> KeyPath {
        let glyph: KeyGlyph = switch shape {
        case .linear: .diamond
        case .eased: .circle
        case .hold: .square
        }
        return KeyPath(
            glyph: glyph, drawSize: Double(SuiteSize.timelineKeyframe), hitSize: Double(SuiteSize.timelineKeyframeHit))
    }

    /// What joins key `a` at `ax` to the next key `b` at `bx`.
    public static func segment(from a: TimelineKey, at ax: Double, to b: TimelineKey, at bx: Double) -> Segment {
        if a.shape == .hold { return Segment(kind: .step, curveGlyphX: nil) }
        let glyph = a.shape == .eased && bx - ax >= curveGlyphGap
        return Segment(kind: .line, curveGlyphX: glyph ? (ax + bx) / 2 : nil)
    }

    /// The time pill for a label `labelWidth` wide: centred on `playheadX`,
    /// clamped inside `visible` less `pillInset` at either end; `height` tall
    /// from y 0. A pill wider than the stretch starts at its lower end.
    public static func pillRect(
        playheadX: Double, labelWidth: Double, height: Double, visible: ClosedRange<Double>
    ) -> CGRect {
        // The label's side padding is SuiteInset.pill's 8 pt each side.
        let width = max(labelWidth, 0) + Double(SuiteSpacing.s * 2)
        let low = visible.lowerBound + pillInset
        let high = visible.upperBound - pillInset
        let x = max(low, min(playheadX - width / 2, high - width))
        return CGRect(x: x, y: 0, width: width, height: height)
    }
}
