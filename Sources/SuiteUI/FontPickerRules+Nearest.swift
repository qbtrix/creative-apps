// FontPickerRules+Nearest.swift: the face a family switch keeps (packet
// docs/blueprints/suiteui/features/font-picker.md). FP-1 declares it as a
// stub returning the family's first face; FP-8 fills it (minimise
// |weight - w| / 100, plus 0.5 when the italic differs; ties go lighter) and
// turns on FontPickerNearestTests.
import SuiteModel

extension FontPickerRules {
    /// The face of `family` nearest `face`; nil for a family with no faces. Stub (FP-1): the first face.
    public static func nearestFace(in family: FontFamily, to face: FontFace) -> FontFace? {
        family.faces.first
    }
}
