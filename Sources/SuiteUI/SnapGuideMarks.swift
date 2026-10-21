// SnapGuideMarks.swift (editor-kernel EK-5): the kernel's `SnapGuides` for one
// drag in a CanvasViewport's overlay (CanvasMarks family): accent alignment
// lines with a small cross at each end, gap lines with end ticks (spacing dashed) and each gap's length in an
// accentFill pill: on the gap's middle when the gap is long enough on screen to
// hold it, else hung beside the gap line so it never hides the ticks or the
// selection handle at a low zoom. One accessibility element, `suite.guides`, valued with the
// `summary`. Takes no clicks; the geometry is static so tests read it.
import SuiteKernel
import SwiftUI

/// One gap's length label in view points: the text, the point its pill is
/// pinned to and which side of that point the pill sits on.
public struct SnapGuideLabel: Equatable, Sendable {
    /// `on`: the pill centres on `at`. `below`: its top-middle is `at`.
    /// `trailing`: its leading-middle is `at`.
    public enum Side: Equatable, Sendable { case on, below, trailing }

    public let text: String
    public let at: CGPoint
    public let side: Side

    public init(text: String, at: CGPoint, side: Side = .on) {
        self.text = text
        self.at = at
        self.side = side
    }
}

/// A drag's alignment lines and gap marks with their distance labels.
public struct SnapGuideMarks: View {
    private let guides: SnapGuides
    private let zoom: Double

    /// `guides` in document pixels; `zoom` in points per pixel.
    public init(guides: SnapGuides, zoom: Double) {
        self.guides = guides
        self.zoom = zoom
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Self.lines(guides, zoom: zoom).stroke(SuiteColor.accent, lineWidth: 1)
            Self.crosses(guides, zoom: zoom).stroke(SuiteColor.accent, lineWidth: 1)
            Self.gaps(guides, spacing: false, zoom: zoom).stroke(SuiteColor.accent, lineWidth: 1)
            Self.gaps(guides, spacing: true, zoom: zoom)
                .stroke(SuiteColor.accent, style: StrokeStyle(lineWidth: 1, dash: [SuiteSpacing.xs]))
            ForEach(Array(Self.labels(guides, zoom: zoom).enumerated()), id: \.offset) { _, label in
                Text(verbatim: label.text)
                    .font(SuiteFont.pill)
                    .foregroundStyle(.white)
                    .padding(SuiteInset.pill)
                    .background { Capsule().fill(SuiteColor.accentFill) }
                    .fixedSize()
                    .frame(width: CGFloat.zero, height: CGFloat.zero, alignment: Self.alignment(label.side))
                    .position(label.at)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Smart guides"))
        .accessibilityValue(Text(verbatim: Self.accessibilityValue(guides)))
        .accessibilityIdentifier("suite.guides")
    }

    /// What the mark's accessibility value reads: the guides' `summary`.
    nonisolated public static func accessibilityValue(_ guides: SnapGuides) -> String { guides.summary }

    private nonisolated static func point(_ axis: SnapLine.Axis, along: Double, across: Double, _ s: Double) -> CGPoint {
        axis == .x ? CGPoint(x: along * s, y: across * s) : CGPoint(x: across * s, y: along * s)
    }

    private nonisolated static func finite(_ values: Double...) -> Bool { values.allSatisfy(\.isFinite) }

    /// Every alignment line in view points: `.x` vertical at `at`, `.y`
    /// horizontal, from `from` to `to`. A non-finite line draws nothing.
    nonisolated public static func lines(_ guides: SnapGuides, zoom: Double) -> Path {
        let s = MotionPathMarks.scale(zoom)
        var path = Path()
        for line in guides.lines where finite(line.at, line.from, line.to) {
            // A line on x fixes x and runs along y, so "along" is the other axis.
            let other: SnapLine.Axis = line.axis == .x ? .y : .x
            path.move(to: point(other, along: line.from, across: line.at, s))
            path.addLine(to: point(other, along: line.to, across: line.at, s))
        }
        return path
    }

    /// A small × at both ends of every alignment line, `SuiteSize.anchor` across
    /// at any zoom, marking the edges the line snapped. A non-finite line draws nothing.
    nonisolated public static func crosses(_ guides: SnapGuides, zoom: Double) -> Path {
        let s = MotionPathMarks.scale(zoom)
        let arm = Double(SuiteSize.anchor) / 2
        var path = Path()
        for line in guides.lines where finite(line.at, line.from, line.to) {
            let other: SnapLine.Axis = line.axis == .x ? .y : .x
            for end in [line.from, line.to] {
                let c = point(other, along: end, across: line.at, s)
                path.move(to: CGPoint(x: c.x - arm, y: c.y - arm))
                path.addLine(to: CGPoint(x: c.x + arm, y: c.y + arm))
                path.move(to: CGPoint(x: c.x - arm, y: c.y + arm))
                path.addLine(to: CGPoint(x: c.x + arm, y: c.y - arm))
            }
        }
        return path
    }

    /// The gaps (`spacing` picks the spacing matches or the plain gaps) in
    /// view points: a line along the gap's axis at `across`, with a
    /// `selectionHandle`-long tick across each end. Non-finite gaps draw nothing.
    nonisolated public static func gaps(_ guides: SnapGuides, spacing: Bool, zoom: Double) -> Path {
        let s = MotionPathMarks.scale(zoom)
        let tick = Double(SuiteSize.selectionHandle) / 2 / s
        var path = Path()
        for gap in guides.gaps where gap.isSpacing == spacing && finite(gap.from, gap.to, gap.across) {
            path.move(to: point(gap.axis, along: gap.from, across: gap.across, s))
            path.addLine(to: point(gap.axis, along: gap.to, across: gap.across, s))
            for end in [gap.from, gap.to] {
                path.move(to: point(gap.axis, along: end, across: gap.across - tick, s))
                path.addLine(to: point(gap.axis, along: end, across: gap.across + tick, s))
            }
        }
        return path
    }

    /// Each gap's label: its `length` in whole points at the gap's middle, or,
    /// when the gap on screen is shorter than its pill plus a handle, hung
    /// beside the gap line (under a gap along x, after one along y), clear of
    /// the end ticks by `SuiteSpacing.xs`.
    nonisolated public static func labels(_ guides: SnapGuides, zoom: Double) -> [SnapGuideLabel] {
        let s = MotionPathMarks.scale(zoom)
        let clear = Double(SuiteSize.selectionHandle) / 2 + Double(SuiteSpacing.xs)
        return guides.gaps.compactMap { gap in
            guard finite(gap.from, gap.to, gap.across) else { return nil }
            let text = "\(gap.length)"
            let middle = gap.from / 2 + gap.to / 2
            let at = point(gap.axis, along: middle, across: gap.across, s)
            // The pill width is estimated at 7 pt a digit plus the insets; measure the text if a
            // label ever holds more than digits.
            let pill = gap.axis == .x
                ? Double(text.count * 7) + Double(SuiteInset.pill.leading + SuiteInset.pill.trailing)
                : Double(SuiteSize.pill)
            guard abs(gap.to - gap.from) * s < pill + Double(SuiteSize.selectionHandle) else {
                return SnapGuideLabel(text: text, at: at)
            }
            return gap.axis == .x
                ? SnapGuideLabel(text: text, at: CGPoint(x: at.x, y: at.y + clear), side: .below)
                : SnapGuideLabel(text: text, at: CGPoint(x: at.x + clear, y: at.y), side: .trailing)
        }
    }

    /// The zero-size frame alignment that puts a pill on its `side` of the pinned point.
    private nonisolated static func alignment(_ side: SnapGuideLabel.Side) -> Alignment {
        switch side {
        case .on: .center
        case .below: .top
        case .trailing: .leading
        }
    }
}
