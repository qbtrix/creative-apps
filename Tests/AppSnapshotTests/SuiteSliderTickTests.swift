// SuiteSliderTickTests.swift: the bar slider's five faint ticks and its marker
// sit in the gap between its label and its value, never on the text. Halo's
// TRANSFORM rows are narrow and carry long labels and wide values ("Position
// Y", "100.0 px"), where ticks on a fixed lane landed inside the letters.
// Renders the real InspectorSliderRow and counts tick blobs along its middle,
// inside the gap measured from the label's and the value's own widths: all
// five, or none when the gap is too narrow to space them, on a mixed row so
// the marker and the fill add no ink of their own. Every marker column lies
// inside that gap, at a low, a middle and a high value (#2963). While typing,
// a 140 pt Rotation row keeps its whole label (#2952). The gap is measured
// from the whole label, so a row that truncates its label to make room for
// the ticks puts the first one outside it and fails. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteSliderTickTests {
    /// label, value, unit, decimals, row width, whether all five ticks must show.
    nonisolated static let cases: [(String, Double, String, Int, CGFloat, Bool)] = [
        ("Position Y", 100, " px", 1, 156, false),  // Halo's TRANSFORM row: the whole label, ticks only if they fit
        ("Rotation", 0, "°", 0, 156, false),
        ("Position Y", 100, " px", 1, 216, true),  // the same row at a full inspector width
        ("X1", 0.42, "", 2, 216, true),  // Flare's and Halo's easing rows
    ]

    @Test(arguments: cases.indices)
    func ticksSitBetweenLabelAndValue(index: Int) throws {
        let (label, value, unit, decimals, width, wide) = Self.cases[index]
        // Mixed: the ticks alone. On a narrow lane a marker between two ticks
        // touches both, so counting around it merged them (3 at 156 pt).
        let row = InspectorSliderRow(label, value: value, in: value...(value + 1000), unit: unit, decimals: decimals, mixed: true) { _ in }
        let image = try Self.render(row, width: width)
        let gap = Self.gap(label, "Mixed", width)
        let blobs = Self.blobs(in: image, across: gap)
        let seen = "\(blobs.count) ticks at \(blobs) in \(gap)"
        if wide {
            #expect(blobs.count == 5, "\(label) at \(width) pt: \(seen), want 5")
        } else {
            #expect(blobs.count == 0 || blobs.count == 5, "\(label) at \(width) pt: \(seen), want 0 or 5")
        }
    }

    /// #2963: Width at 640 pt, Stroke at 1.5 pt and Y2 at 1.45, at either end
    /// of the track and in its middle: every marker column of the row lies in
    /// the gap, none on the label or the value.
    @Test(arguments: [("Width", 640.0, " pt", 0), ("Stroke", 1.5, " pt", 1), ("Y2", 1.45, "", 2)])
    func markerNeverTouchesTheText(label: String, value: Double, unit: String, decimals: Int) throws {
        for range in [value...(value + 10), (value - 5)...(value + 5), (value - 10)...value] {
            let row = InspectorSliderRow(label, value: value, in: range, unit: unit, decimals: decimals) { _ in }
            let image = try Self.render(row, width: 216)
            let gap = Self.gap(label, NumericInput.text(value, decimals: decimals, unit: unit), 216)
            let marks = Self.markerColumns(in: image)
            #expect(!marks.isEmpty, "\(label) over \(range): no marker")
            let scale = SnapshotHost.scale
            #expect(marks.allSatisfy { gap.contains(CGFloat($0) / scale) }, "\(label) over \(range): marker at \(marks) outside \(gap)")
        }
    }

    /// #2952: the typing field takes the gap, so the label keeps every letter;
    /// its pixels match the same label drawn alone on the row.
    @Test func typingKeepsTheWholeLabel() throws {
        let width: CGFloat = 140
        let bar = ScrubField.Bar(preview: .editing)
        let row = InspectorSliderRow(
            "Rotation", value: 45, in: -180...180, step: nil, unit: "°", decimals: 0, bar: bar, onChange: { _ in }, onEnd: {})
        let alone = Text("Rotation").font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
            .fixedSize().padding(.horizontal, SuiteSpacing.m)
            .frame(width: width, height: SuiteSize.studioRow, alignment: .leading).background(SuiteColor.panelRaised)
        let typing = try Self.render(row, width: width), reference = try Self.render(alone, width: width)
        let scale = SnapshotHost.scale
        let labelEnd = SuiteSpacing.m + Self.width(Text("Rotation").font(SuiteFont.inspectorLabel))
        var worst = 0
        for y in Int(SuiteSpacing.xs * scale)..<Int((SuiteSize.studioRow - SuiteSpacing.xs) * scale) {
            for x in Int(SuiteSpacing.m * scale)..<Int((labelEnd + 1) * scale) {
                worst = max(worst, zip(Self.pixel(typing, x, y), Self.pixel(reference, x, y)).map { abs($0 - $1) }.max() ?? 0)
            }
        }
        #expect(worst <= 24, "the typing row's label differs from the whole label by \(worst)")
    }

    private static func render(_ row: some View, width: CGFloat) throws -> RGBAImage {
        let size = CGSize(width: width, height: SuiteSize.studioRow)
        return try #require(SnapshotHost(appearance: .light).image(row.frame(width: width), size: size))
    }

    /// The gap between the label and the value, 2 pt clear of each text so its anti-aliased edge doesn't count.
    private static func gap(_ label: String, _ value: String, _ width: CGFloat) -> ClosedRange<CGFloat> {
        let labelWidth = Self.width(Text(label).font(SuiteFont.inspectorLabel))
        let valueWidth = Self.width(Text(value).font(SuiteFont.inspectorValue))
        return (SuiteSpacing.m + labelWidth + 2)...(width - SuiteSpacing.m - valueWidth - 2)
    }

    private static func width(_ text: some View) -> CGFloat {
        NSHostingView(rootView: text.lineLimit(1).fixedSize()).fittingSize.width
    }

    private static func pixel(_ image: RGBAImage, _ x: Int, _ y: Int) -> [Int] {
        let i = (y * image.width + x) * 4
        return (0..<3).map { Int(image.bytes[i + $0]) }
    }

    /// Whether the pixel at (`x`, `y`) differs from its column's own background, sampled near the row's top.
    private static func inked(_ image: RGBAImage, _ x: Int, _ y: Int) -> Bool {
        let ground = pixel(image, x, Int(SuiteSpacing.xxs * SnapshotHost.scale))
        return (zip(pixel(image, x, y), ground).map { abs($0 - $1) }.max() ?? 0) > 20
    }

    /// The columns the marker inks: just inside its top end, above the text
    /// and the ticks, clear of the row's rounded corners.
    private static func markerColumns(in image: RGBAImage) -> [Int] {
        let y = Int((SuiteSpacing.markerInset + 1) * SnapshotHost.scale)
        let corner = Int(SuiteRadius.row * SnapshotHost.scale)
        guard corner < image.width - corner else { return [] }
        return (corner..<(image.width - corner)).filter { inked(image, $0, y) }
    }

    /// The cores of the ink runs along the row's middle line within `gap`
    /// (points), each column against its own background, as point ranges.
    /// A core is a run at 60% or more of the darkest column's ink, so the
    /// faint anti-aliased edges of two close ticks don't join them into one.
    private static func blobs(in image: RGBAImage, across gap: ClosedRange<CGFloat>) -> [ClosedRange<CGFloat>] {
        let scale = SnapshotHost.scale
        let middle = Int(SuiteSize.studioRow / 2 * scale)
        let from = Int((gap.lowerBound * scale).rounded(.up)), to = Int((gap.upperBound * scale).rounded(.down))
        guard from < to else { return [] }
        let ground = Int(SuiteSpacing.xxs * scale)
        let ink = (from...to).map { x in zip(pixel(image, x, middle), pixel(image, x, ground)).map { abs($0 - $1) }.max() ?? 0 }
        let core = max(21, (ink.max() ?? 0) * 6 / 10)
        var runs: [ClosedRange<CGFloat>] = []
        var start: Int?
        for i in 0...ink.count {
            let value = i < ink.count ? ink[i] : 0
            if value >= core, start == nil { start = i }
            if value < core, let first = start {
                runs.append(CGFloat(from + first) / scale...CGFloat(from + i - 1) / scale)
                start = nil
            }
        }
        return runs
    }
}
