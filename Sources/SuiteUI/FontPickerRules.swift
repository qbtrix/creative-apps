// FontPickerRules.swift: the font picker's one home for search and face order
// (packet docs/blueprints/suiteui/features/font-picker.md, rule 20: no app
// filters fonts itself). `filtered` folds case and diacritics on both sides and
// lists the families whose name starts with the query, in name order, then
// those that only contain it; `orderedFaces` sorts by weight, roman before
// italic (FP-5). The nearest-face rule is FontPickerRules+Nearest.swift (FP-8),
// so the two fills share no file.
import Foundation
import SuiteModel

public enum FontPickerRules {
    /// The families matching `query`: prefix matches in name order, then substring
    /// matches in name order, ignoring case and diacritics. An empty query keeps every
    /// family in the order given.
    public static func filtered(_ families: [FontFamily], query: String) -> [FontFamily] {
        let needle = folded(query)
        guard !needle.isEmpty else { return families }
        var prefix: [(key: String, family: FontFamily)] = []
        var contains: [(key: String, family: FontFamily)] = []
        for family in families {
            let key = folded(family.name)
            if key.hasPrefix(needle) {
                prefix.append((key, family))
            } else if key.contains(needle) {
                contains.append((key, family))
            }
        }
        return inNameOrder(prefix) + inNameOrder(contains)
    }

    /// The family's faces in menu order: lighter first, and at one weight the roman
    /// face before the italic. Faces that tie on both keep the order given.
    public static func orderedFaces(_ family: FontFamily) -> [FontFace] {
        family.faces.enumerated().sorted { a, b in
            if a.element.weight != b.element.weight { return a.element.weight < b.element.weight }
            if a.element.italic != b.element.italic { return !a.element.italic && b.element.italic }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// `text` with case and diacritics removed, for matching only (never shown).
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func inNameOrder(_ matches: [(key: String, family: FontFamily)]) -> [FontFamily] {
        matches.sorted { $0.key != $1.key ? $0.key < $1.key : $0.family.name < $1.family.name }.map(\.family)
    }
}
