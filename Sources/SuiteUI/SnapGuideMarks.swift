// SnapGuideMarks.swift (editor-kernel EK-5): the kernel's `SnapGuides` for one
// drag in a CanvasViewport's overlay (CanvasMarks family): accent alignment
// lines, gap lines with end ticks (spacing dashed) and each gap's length in an
// accentFill pill. One accessibility element, `suite.guides`, valued with the
// `summary`. Takes no clicks; the geometry is static so tests read it.
import SuiteKernel
import SwiftUI

/// One gap's length label in view points: the text and where its pill centres.
public struct SnapGuideLabel: Equatable, Sendable {
    public let text: String
    public let center: CGPoint

    public init(text: String, center: CGPoint) {
        self.text = text
        self.center = center
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
                    .position(label.center)
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

    /// Each gap's label: its `length` in whole points, at the gap's middle.
    nonisolated public static func labels(_ guides: SnapGuides, zoom: Double) -> [SnapGuideLabel] {
        let s = MotionPathMarks.scale(zoom)
        return guides.gaps.compactMap { gap in
            guard finite(gap.from, gap.to, gap.across) else { return nil }
            let middle = gap.from / 2 + gap.to / 2
            return SnapGuideLabel(text: "\(gap.length)", center: point(gap.axis, along: middle, across: gap.across, s))
        }
    }
}
