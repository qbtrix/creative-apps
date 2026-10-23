// ColorRowFitTests.swift: a color row's label and hex code fit. The row is the label, then the swatch, the hex
// field and the eyedropper button at fixed widths; when those take too much, the label ends in "…" (Flare's SCENE
// row read "Bac…und"). This measures "Background", the longest label any app gives the row, in the row's label
// font against the row inside Flare's inspector column (the editor panel and its gutters), where that row lives;
// "Stroke", the longest label a row at the ideal inspector width carries; and "#FFFFFF" in its value font.
// macOS only.
#if canImport(AppKit)
import AppKit
import Testing

@testable import SuiteUI

@Suite struct ColorRowFitTests {
    private static func width(_ text: String, _ font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private static let size = NSFont.preferredFont(forTextStyle: .subheadline).pointSize

    /// What a row in a `column` pt inspector leaves its label: the inspector's two gutters, the row's padding,
    /// the swatch, the hex field and the eyedropper button, and the gaps between them.
    private static func room(_ column: CGFloat) -> CGFloat {
        let row = column - 4 * SuiteSpacing.m
        return row - 2 * SuiteSpacing.m - SuiteSize.swatch.width - 3 * SuiteSpacing.s - SuiteSize.hexField
            - SuiteSize.iconButtonHit
    }

    @Test func backgroundFitsBesideTheSwatchHexAndEyedropperInTheEditorInspector() {
        let room = Self.room(SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m)
        let label = Self.width("Background", .systemFont(ofSize: Self.size))
        #expect(label <= room, "\"Background\" is \(label) pt; the row leaves it \(room) pt")
    }

    @Test func strokeFitsBesideTheSwatchHexAndEyedropperAtTheIdealInspectorWidth() {
        let room = Self.room(SuiteSize.inspectorWidth.ideal)
        let label = Self.width("Stroke", .systemFont(ofSize: Self.size))
        #expect(label <= room, "\"Stroke\" is \(label) pt; the row leaves it \(room) pt")
    }

    @Test func theWidestHexCodeFitsItsField() {
        let hex = Self.width("#FFFFFF", .systemFont(ofSize: Self.size, weight: .semibold))
        #expect(hex <= SuiteSize.hexField, "\"#FFFFFF\" is \(hex) pt; the field is \(SuiteSize.hexField) pt")
    }
}
#endif
