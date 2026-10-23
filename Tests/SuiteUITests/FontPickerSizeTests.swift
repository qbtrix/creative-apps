// FontPickerSizeTests.swift: how the font picker's Size row reads and drags
// (FontPickerRules+Size.swift; findings #4778, #4779). It shows whole points,
// and its bar spans 1...200 so common sizes sit apart on it, while typing still
// reaches all of TextRules.sizes. The mutation plan `SuiteUI.FontPickerSize`
// names these tests. macOS only.
import SuiteModel
import Testing

@testable import SuiteUI

@Suite struct FontPickerSizeTests {
    @Test func readsWholePoints() {
        let text = NumericInput.text(12, decimals: FontPickerRules.sizeDecimals, unit: "pt")
        #expect(text == "12 pt", "the Size row reads \(text)")
    }

    @Test func barSpansCommonSizes() {
        let bar = FontPickerRules.sizeBarRange
        let gap = (FontPicker.sizeTrack.position(of: 36) - FontPicker.sizeTrack.position(of: 12)) / (bar.upperBound - bar.lowerBound)
        #expect(gap > 0.1, "12 pt and 36 pt sit \(gap) of the bar apart")
        #expect(bar.upperBound < TextRules.sizes.upperBound, "the bar spans every size")
    }

    @Test func barClampsTypedSizes() {
        #expect(FontPickerRules.sizeBarPosition(1_600) == FontPickerRules.sizeBarRange.upperBound)
        #expect(FontPickerRules.sizeBarPosition(0) == FontPickerRules.sizeBarRange.lowerBound)
        #expect(FontPickerRules.sizeBarPosition(.nan) == FontPickerRules.sizeBarRange.lowerBound)
        #expect(FontPickerRules.sizeBarPosition(36) == 36)
    }
}
