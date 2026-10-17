// PresetLabelFitTests.swift: every easing preset label fits its chip at the easing inspector's ideal width. A chip is
// one line, so a label that is too wide ends in "…". This measures the widest preset in the caption font the chip
// draws with, plus the chip's side padding, against one column of ChoiceChips inside the inspector's gutters. macOS only.
#if canImport(AppKit)
import AppKit
import Testing

@testable import SuiteUI

@Suite struct PresetLabelFitTests {
    @Test func theWidestPresetLabelFitsItsColumnAtTheIdealInspectorWidth() {
        let labels = ["Linear", "Ease", "Ease In", "Ease Out", "Ease In-Out", "Hold"]
        let font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        let widest = labels.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let column = (SuiteSize.inspectorWidth.ideal - 2 * SuiteSpacing.m - 2 * SuiteSpacing.xs) / 3
        #expect(widest + 2 * SuiteChipStyle.presetPadding <= column,
                "widest preset label \(widest) pt plus padding is wider than its \(column) pt column")
    }
}
#endif
