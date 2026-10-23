// FontPickerRules+Nearest.swift: the face a family switch keeps (packet
// docs/blueprints/suiteui/features/font-picker.md, FP-8). The nearest face
// minimises |weight - w| / 100, plus 0.5 when the italic differs; ties go to
// the lighter face, then to the earlier one. The cost is kept in hundredths
// (|weight - w| + 50) so it stays an exact integer.
import SuiteModel

extension FontPickerRules {
    /// The face of `family` nearest `face`; nil for a family with no faces.
    public static func nearestFace(in family: FontFamily, to face: FontFace) -> FontFace? {
        var best: (face: FontFace, cost: Int)?
        for candidate in family.faces {
            let cost = abs(candidate.weight - face.weight) + (candidate.italic != face.italic ? 50 : 0)
            guard let current = best else { best = (candidate, cost); continue }
            if cost < current.cost || (cost == current.cost && candidate.weight < current.face.weight) {
                best = (candidate, cost)
            }
        }
        return best?.face
    }
}
