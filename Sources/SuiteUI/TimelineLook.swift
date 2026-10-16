// TimelineLook.swift: the timeline strip's look rules, with no SwiftUI: they
// answer with SuitePalette entries and rects, so a lane, the playhead and a
// later CoreGraphics lane layer draw alike (timeline packet, TL-5). A key's
// fill follows only its own state, never the track's selection (#1423). Its
// 1 pt edge carries contrast on a clip (#62): white when picked in the dark
// appearances, the primary ink in the light ones, where white on a clip
// measures 1.46:1. The time pill stays inside the visible stretch.
import Foundation

public enum TimelineLook {
    /// A key's edge: a palette color and a width in points.
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
    }

    /// What joins two consecutive keys, and the x of the eased curve glyph when there is one.
    public struct Segment: Hashable, Sendable {
        public enum Kind: Hashable, Sendable { case line, step }
        public let kind: Kind
        public let curveGlyphX: Double?
    }

    /// The accent 24 % into the panel: Dark, Light, Dark + Increase Contrast, Light + Increase Contrast.
    public static let clipFill = SuiteHex(0x233A5B, 0xC1D8F6, 0x2A3D57, 0xC4D9F4)
    /// A picked key's edge: white in the dark appearances, the primary text ink in the light ones.
    public static let pickedEdge = SuiteHex(0xFFFFFF, 0x1D1D1F, 0xFFFFFF, 0x000000)
    /// The narrowest gap between two keys that shows the eased curve glyph.
    public static let curveGlyphGap = 24.0
    /// The room the time pill keeps from either end of the visible stretch.
    public static let pillInset = Double(SuiteSpacing.xxs)

    /// The fill of `key` on `track` with the playhead at `playhead`.
    public static func keyFill<ID>(_ key: TimelineKey, on track: TimelineTrack<ID>, playhead: Int) -> SuiteHex {
        keyFill(picked: track.pickedFrames.contains(key.frame), atPlayhead: key.frame == playhead)
    }

    /// The fill of a key that is `picked` or `atPlayhead`.
    public static func keyFill(picked: Bool, atPlayhead: Bool) -> SuiteHex {
        atPlayhead ? SuitePalette.stateKeyed : picked ? SuitePalette.accent : SuitePalette.textSecondary
    }

    /// The 1 pt edge of a key that is `picked` or not.
    public static func keyEdge(picked: Bool) -> Edge {
        Edge(color: picked ? pickedEdge : SuitePalette.panel, width: 1)
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

    /// The row a track name shows: pressed, selected, hovered or plain.
    public enum NameRow: Hashable, Sendable { case plain, hovered, pressed, selected }

    /// A track name's row: a press shows at once, even on the selected track;
    /// a selected row keeps its tint under the pointer; hover is only for an
    /// idle row (every control shows hover, pressed and selected, lead rule 10).
    public static func nameRow(selected: Bool, hovered: Bool, pressed: Bool) -> NameRow {
        if pressed { return .pressed }
        if selected { return .selected }
        return hovered ? .hovered : .plain
    }

    /// The time pill for a label `labelWidth` wide, `height` tall from y 0:
    /// centred on `playheadX`, clamped inside `visible` less `pillInset` at
    /// either end. A pill wider than the stretch starts at its lower end.
    public static func pillRect(
        playheadX: Double, labelWidth: Double, height: Double, visible: ClosedRange<Double>
    ) -> CGRect {
        // The label's side padding is SuiteInset.pill's 8 pt each side.
        let width = max(labelWidth, 0) + Double(SuiteSpacing.s * 2)
        let (low, high) = (visible.lowerBound + pillInset, visible.upperBound - pillInset)
        let x = max(low, min(playheadX - width / 2, high - width))
        return CGRect(x: x, y: 0, width: width, height: height)
    }
}
