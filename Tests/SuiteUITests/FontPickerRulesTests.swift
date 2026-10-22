// FontPickerRulesTests.swift: the font picker's search and face order
// (FontPickerRules.swift; packet docs/blueprints/suiteui/features/font-picker.md,
// FP-5's acceptance row). Search puts families whose name starts with the
// query first, then those containing it, folding case and diacritics on both
// sides; faces order by weight, roman before italic at one weight. Written by
// FP-2 against FP-1's stubs and disabled until FP-5 fills the bodies; the
// mutation plan `SuiteUI.FontPickerRules` names these tests. macOS only.
import SuiteModel
import SuiteUI
import Testing

private func family(_ name: String, _ faces: [FontFace] = [FontFace(name: "Regular", weight: 400, italic: false)]) -> FontFamily {
    FontFamily(name: name, faces: faces)
}

@Suite struct FontPickerRulesTests {
    @Test(.disabled("waits on FP-5")) func prefixFirst() {
        let families = [family("Big Grotesk"), family("Serif"), family("Grotesk"), family("Mono")]
        #expect(FontPickerRules.filtered(families, query: "gro").map(\.name) == ["Grotesk", "Big Grotesk"])
    }

    @Test(.disabled("waits on FP-5")) func prefixMatchesComeInNameOrder() {
        let families = [family("Grotesk Wide"), family("Garamond"), family("Grotesk")]
        #expect(FontPickerRules.filtered(families, query: "GRO").map(\.name) == ["Grotesk", "Grotesk Wide"])
    }

    @Test(.disabled("waits on FP-5")) func foldsDiacritics() {
        let families = [family("Mono"), family("Serif"), family("Café Sans")]
        #expect(Set(FontPickerRules.filtered(families, query: "é").map(\.name)) == ["Serif", "Café Sans"])
        #expect(FontPickerRules.filtered(families, query: "cafe").map(\.name) == ["Café Sans"])
    }

    @Test(.disabled("waits on FP-5")) func anEmptyQueryKeepsEveryFamily() {
        let families = [family("Serif"), family("Mono")]
        #expect(FontPickerRules.filtered(families, query: "").map(\.name) == ["Serif", "Mono"])
    }

    @Test(.disabled("waits on FP-5")) func romanBeforeItalic() {
        let shuffled = family("Grotesk", [
            FontFace(name: "Bold Italic", weight: 700, italic: true), FontFace(name: "Italic", weight: 400, italic: true),
            FontFace(name: "Bold", weight: 700, italic: false), FontFace(name: "Light", weight: 300, italic: false),
            FontFace(name: "Regular", weight: 400, italic: false),
        ])
        #expect(FontPickerRules.orderedFaces(shuffled).map(\.name) == ["Light", "Regular", "Italic", "Bold", "Bold Italic"])
    }
}
