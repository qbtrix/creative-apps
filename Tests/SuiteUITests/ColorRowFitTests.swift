// ColorRowFitTests.swift: a color row's label and hex code fit at the ideal inspector width. The row is the label,
// then the swatch and the hex field at fixed widths; when those two take too much, the label ends in "…" (Flare's
// SCENE row read "Bac…und"). This measures "Background", the longest label any app gives the row, in the
// row's label font, and "#FFFFFF" in its value font, against the row inside the inspector's two gutters. macOS only.
#if canImport(AppKit)
import AppKit
import Testing

@testable import SuiteUI

@Suite struct ColorRowFitTests {
    private static func width(_ text: String, _ font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private static let size = NSFont.preferredFont(forTextStyle: .subheadline).pointSize

    @Test func backgroundFitsBesideTheSwatchAndHexAtTheIdealInspectorWidth() {
        let row = SuiteSize.inspectorWidth.ideal - 4 * SuiteSpacing.m
        let room = row - 2 * SuiteSpacing.m - SuiteSize.swatch.width - 2 * SuiteSpacing.s - SuiteSize.hexField
        let label = Self.width("Background", .systemFont(ofSize: Self.size))
        #expect(label <= room, "\"Background\" is \(label) pt; the row leaves it \(room) pt")
    }

    @Test func theWidestHexCodeFitsItsField() {
        let hex = Self.width("#FFFFFF", .systemFont(ofSize: Self.size, weight: .semibold))
        #expect(hex <= SuiteSize.hexField, "\"#FFFFFF\" is \(hex) pt; the field is \(SuiteSize.hexField) pt")
    }
}
#endif
