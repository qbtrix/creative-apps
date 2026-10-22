// FontPickerNearestTests.swift: the face a family switch keeps
// (FontPickerRules+Nearest.swift; packet docs/blueprints/suiteui/features/font-picker.md,
// FP-8's acceptance row). The nearest face minimises
// |weight - w| / 100 + 0.5 when the italic differs; ties go to the lighter
// face; an empty family gives nil. Written by FP-2 against FP-1's stub and
// disabled until FP-8 fills the body; the mutation plan
// `SuiteUI.FontPickerNearest` names these tests. macOS only.
import SuiteModel
import SuiteUI
import Testing

private let regular = FontFace(name: "Regular", weight: 400, italic: false)
private let italic = FontFace(name: "Italic", weight: 400, italic: true)
private let medium = FontFace(name: "Medium", weight: 500, italic: false)
private let semibold = FontFace(name: "Semibold", weight: 600, italic: false)
private let bold = FontFace(name: "Bold", weight: 700, italic: false)
private let boldItalic = FontFace(name: "Bold Italic", weight: 700, italic: true)
private let black = FontFace(name: "Black", weight: 900, italic: false)

@Suite struct FontPickerNearestTests {
    @Test(.disabled("waits on FP-8")) func keepsTheNearestWeight() {
        let family = FontFamily(name: "Grotesk", faces: [regular, black, semibold])
        #expect(FontPickerRules.nearestFace(in: family, to: bold) == semibold)
    }

    @Test(.disabled("waits on FP-8")) func withoutItalicsKeepsTheWeight() {
        let family = FontFamily(name: "Grotesk", faces: [regular, bold, black])
        #expect(FontPickerRules.nearestFace(in: family, to: boldItalic) == bold)
    }

    @Test(.disabled("waits on FP-8")) func keepsItalic() {
        let family = FontFamily(name: "Serif", faces: [regular, italic])
        #expect(FontPickerRules.nearestFace(in: family, to: italic) == italic)
        #expect(FontPickerRules.nearestFace(in: FontFamily(name: "Grotesk", faces: [bold, regular, boldItalic]),
                                            to: boldItalic) == boldItalic)
    }

    @Test(.disabled("waits on FP-8")) func tiesGoLighter() {
        let family = FontFamily(name: "Grotesk", faces: [semibold, regular])
        #expect(FontPickerRules.nearestFace(in: family, to: medium) == regular)
    }

    @Test(.disabled("waits on FP-8")) func anEmptyFamilyGivesNil() {
        #expect(FontPickerRules.nearestFace(in: FontFamily(name: "Empty", faces: []), to: bold) == nil)
    }
}
