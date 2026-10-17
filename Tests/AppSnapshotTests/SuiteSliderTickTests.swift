// SuiteSliderTickTests.swift: the bar slider's five faint ticks sit in the
// gap between its label and its value, never on the text. Halo's TRANSFORM
// rows are narrow and carry long labels and wide values ("Position Y",
// "100.0 px"), where ticks on a fixed lane landed inside the letters. Renders
// the real InspectorSliderRow and counts tick blobs along its middle, inside
// the gap measured from the label's and the value's own widths: all five, or
// none when the gap is too narrow to space them. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteSliderTickTests {
    /// label, value, unit, decimals, row width, whether all five ticks must show.
    nonisolated static let cases: [(String, Double, String, Int, CGFloat, Bool)] = [
        ("Position Y", 100, " px", 1, 156, false),  // Halo's TRANSFORM row: no room, no ticks
        ("Rotation", 0, "°", 0, 156, false),
        ("Position Y", 100, " px", 1, 216, true),  // the same row at a full inspector width
        ("X1", 0.42, "", 2, 216, true),  // Flare's and Halo's easing rows
    ]

    @Test(arguments: cases.indices)
    func ticksSitBetweenLabelAndValue(index: Int) throws {
        let (label, value, unit, decimals, width, wide) = Self.cases[index]
        // The value at the range's start: no fill, and the marker sits at the bar's left edge, outside the gap.
        let row = InspectorSliderRow(label, value: value, in: value...(value + 1000), unit: unit, decimals: decimals) { _ in }
        let size = CGSize(width: width, height: SuiteSize.studioRow)
        let image = try #require(SnapshotHost(appearance: .light).image(row.frame(width: width), size: size))
        let labelWidth = Self.width(Text(label).font(SuiteFont.inspectorLabel))
        let valueWidth = Self.width(Text(NumericInput.text(value, decimals: decimals, unit: unit)).font(SuiteFont.inspectorValue))
        // 2 pt clear of each text, so its anti-aliased edge doesn't count.
        let gap = (SuiteSpacing.m + labelWidth + 2)...(width - SuiteSpacing.m - valueWidth - 2)
        let blobs = Self.blobs(in: image, across: gap)
        if wide {
            #expect(blobs == 5, "\(label) at \(width) pt: \(blobs) ticks in the gap \(gap), want 5")
        } else {
            #expect(blobs == 0 || blobs == 5, "\(label) at \(width) pt: \(blobs) ticks in the gap \(gap), want 0 or 5")
        }
    }

    private static func width(_ text: some View) -> CGFloat {
        NSHostingView(rootView: text.lineLimit(1).fixedSize()).fittingSize.width
    }

    /// Runs of ink along the row's middle line within `gap` (points), against
    /// the bar's own fill sampled above the line.
    private static func blobs(in image: RGBAImage, across gap: ClosedRange<CGFloat>) -> Int {
        let scale = SnapshotHost.scale
        func pixel(_ x: Int, _ y: Int) -> [Int] {
            let i = (y * image.width + x) * 4
            return (0..<3).map { Int(image.bytes[i + $0]) }
        }
        let middle = Int(SuiteSize.studioRow / 2 * scale)
        let from = Int((gap.lowerBound * scale).rounded(.up)), to = Int((gap.upperBound * scale).rounded(.down))
        guard from < to else { return 0 }
        let fill = pixel((from + to) / 2, Int(SuiteSpacing.xs * scale))
        var runs = 0
        var inRun = false
        for x in from...to {
            let p = pixel(x, middle)
            let ink = (zip(p, fill).map { abs($0 - $1) }.max() ?? 0) > 20
            if ink && !inRun { runs += 1 }
            inRun = ink
        }
        return runs
    }
}
