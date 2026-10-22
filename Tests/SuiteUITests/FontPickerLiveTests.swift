// FontPickerLiveTests.swift: the gallery's `font-picker` page on live families
// (GalleryFontPicker.swift, FP-6; packet
// docs/blueprints/suiteui/features/font-picker.md). With live services the
// page lists the live font list's families, every one of them; under
// -SuiteGalleryFakes, or with no live list, it keeps FakeText's three.
// macOS only.
import SuiteModel
import Testing

@testable import SuiteUI

/// A live font list stand-in: `count` one-face families, none named like FakeText's.
private struct ListedFonts: FontListing {
    let count: Int

    func families() -> [FontFamily] {
        (0..<count).map { FontFamily(name: "Live \($0)", faces: [FontFace(name: "Regular", weight: 400, italic: false)]) }
    }
}

@Suite struct FontPickerLiveTests {
    static let live = ListedFonts(count: 7)
    static let fakes = FakeText().families()

    @Test func liveServicesListTheLiveFamilies() {
        let listed = GalleryFontPicker.families(fakes: false, live: Self.live)
        #expect(listed.count == Self.live.families().count, "the page lists \(listed.count) families, the live list has 7")
        #expect(listed == Self.live.families(), "the page isn't on the live families: \(listed.map(\.name))")
    }

    @Test func fakesKeepFakeTextsFamilies() {
        #expect(GalleryFontPicker.families(fakes: true, live: Self.live) == Self.fakes, "-SuiteGalleryFakes left FakeText")
    }

    @Test func noLiveListKeepsFakeTextsFamilies() {
        #expect(GalleryFontPicker.families(fakes: false, live: nil) == Self.fakes, "no live list but not FakeText")
    }
}
