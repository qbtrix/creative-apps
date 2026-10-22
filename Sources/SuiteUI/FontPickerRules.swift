// FontPickerRules.swift: the font picker's one home for search and face order
// (packet docs/blueprints/suiteui/features/font-picker.md, rule 20: no app
// filters fonts itself). FP-1 declares the rules as stubs that keep the input
// order; FP-5 fills `filtered` (prefix matches first, then substring, folding
// case and diacritics) and `orderedFaces` (by weight, roman before italic),
// and turns on FontPickerRulesTests. The nearest-face rule is
// FontPickerRules+Nearest.swift (FP-8), so the two fills share no file.
import SuiteModel

public enum FontPickerRules {
    /// The families matching `query`. Stub (FP-1): every family, in the order given.
    public static func filtered(_ families: [FontFamily], query: String) -> [FontFamily] {
        families
    }

    /// The family's faces in menu order. Stub (FP-1): the faces in the order given.
    public static func orderedFaces(_ family: FontFamily) -> [FontFace] {
        family.faces
    }
}
