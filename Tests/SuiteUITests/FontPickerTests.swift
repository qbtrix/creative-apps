// FontPickerTests.swift: the font picker view's own logic (FontPicker.swift,
// FP-3; packet docs/blueprints/suiteui/features/font-picker.md, FP-4). Rows
// are keyed by family name, so a filter run twice keeps the same ids; a pick
// reports once, and a pick that changes nothing reports nothing. Choosing a
// family keeps the size and takes the nearest face. macOS only.
import SuiteModel
import Testing

@testable import SuiteUI

@MainActor @Suite struct FontPickerTests {
    static let regular = FontFace(name: "Regular", weight: 400, italic: false)
    static let bold = FontFace(name: "Bold", weight: 700, italic: false)
    static let families = FakeText().families()
    static let start = FontPick(family: "Mono", face: regular, size: 12)

    @Test func rowsHaveStableIds() {
        let first = FontPicker.rows(Self.families, query: "")
        #expect(first == Self.families.map(\.name), "rows aren't keyed by family name: \(first)")
        #expect(FontPicker.rows(Self.families, query: "") == first, "a second filter changed the ids")
        #expect(Set(first).count == first.count, "two rows share an id")
        let narrowed = FontPicker.rows(Self.families, query: "sys")
        #expect(narrowed.allSatisfy(first.contains), "a filter made up an id: \(narrowed)")
        #expect(FontPicker.rows(Self.families, query: "sys") == narrowed, "a repeated query changed the ids")
    }

    @Test func aPickCallsOnPickOnce() throws {
        var picks: [FontPick] = []
        let picker = FontPicker(families: Self.families, pick: Self.start) { picks.append($0) }
        let system = try #require(Self.families.first { $0.name == "System UI" })
        picker.choose(FontPicker.choosing(family: system, from: Self.start))
        #expect(picks.count == 1, "one family pick reported \(picks.count) times")
        #expect(picks.last?.family == "System UI" && picks.last?.size == 12, "the pick is \(String(describing: picks.last))")
    }

    @Test func anUnchangedPickReportsNothing() throws {
        var picks: [FontPick] = []
        let picker = FontPicker(families: Self.families, pick: Self.start) { picks.append($0) }
        let mono = try #require(Self.families.first { $0.name == "Mono" })
        picker.choose(FontPicker.choosing(family: mono, from: Self.start))
        picker.choose(FontPicker.choosing(face: Self.regular, from: Self.start))
        picker.choose(FontPicker.choosing(size: 12, from: Self.start))
        #expect(picks.isEmpty, "re-picking the current value reported \(picks)")
    }

    @Test func faceAndSizePicks() {
        let bold = FontPicker.choosing(face: Self.bold, from: Self.start)
        #expect(bold == FontPick(family: "Mono", face: Self.bold, size: 12))
        #expect(FontPicker.choosing(size: 36, from: Self.start)?.size == 36)
        #expect(FontPicker.choosing(size: 36.4, from: Self.start)?.size == 36, "the size isn't a whole point")
        #expect(FontPicker.choosing(size: 99_999, from: Self.start)?.size == TextRules.sizes.upperBound)
        #expect(FontPicker.choosing(size: 0, from: Self.start)?.size == TextRules.sizes.lowerBound)
        #expect(FontPicker.choosing(size: .nan, from: Self.start) == nil, "NaN made a pick")
    }

    @Test func familyPickTakesANearbyFaceAndKeepsTheSize() throws {
        let serif = try #require(Self.families.first { $0.name == "Serif" })
        let from = FontPick(family: "System UI", face: Self.bold, size: 36)
        let next = try #require(FontPicker.choosing(family: serif, from: from))
        #expect(next.family == "Serif" && next.size == 36, "the pick is \(next)")
        #expect(serif.faces.contains(next.face), "\(next.face) isn't one of Serif's faces")
    }

    @Test func faceMenuListsTheFamilysFaces() throws {
        let system = try #require(Self.families.first { $0.name == "System UI" })
        #expect(FontPicker.faceOptions(system).map(\.title).sorted() == ["Bold", "Regular"])
        #expect(FontPicker.faceOptions(nil).isEmpty, "a missing family has faces")
    }
}
