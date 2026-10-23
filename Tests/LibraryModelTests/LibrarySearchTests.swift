// LibrarySearchTests.swift: MD-20 (metadata-more), the search field's value on
// the `cameras` fixture. Tokens AND together; `field:value` narrows to keyword,
// title, caption, camera, lens, iso, f or mm; iso, f and mm compare numbers
// (`>`, `<`, `>=`, `<=` or equal) and a bad number makes the token plain text;
// a quoted phrase is one token; plain text matches the name, a keyword, the
// title, the caption, the camera or the lens, in any case. Written before its
// code (rule 13, MD-19); MD-20 enabled them. Runs on Linux and macOS.
import CoreColor
@testable import LibraryModel
import Testing

private let cameras = LibraryFixtures.photos(named: "cameras")

/// The `cameras` photos `text` lets through, as their numbers (IMG_0007 is 7).
private func matching(_ text: String) -> [Int] {
    let search = PhotoSearch(text)
    return cameras.filter(search.matches).compactMap { Int($0.name.dropFirst(4)) }
}

@Test func emptySearchLetsEveryPhotoThrough() {
    #expect(matching("").count == 24)
    #expect(matching("   ").count == 24)
}

@Test func lensFieldMatchesThatLens() {
    // n mod 3 == 2 is the 50mm F1.8: eight photos.
    #expect(matching("lens:50") == [2, 5, 8, 11, 14, 17, 20, 23])
    #expect(matching("LENS:50mm") == [2, 5, 8, 11, 14, 17, 20, 23])
    #expect(matching("lens:macro") == [3, 6, 9, 12, 15, 18, 21])
}

@Test func isoComparesNumbers() {
    // ISO doubles from 100 to 6400 in steps of seven; IMG_0024 has none.
    #expect(matching("iso:>1600") == [6, 7, 13, 14, 20, 21])
    #expect(matching("iso:>=1600") == [5, 6, 7, 12, 13, 14, 19, 20, 21])
    #expect(matching("iso:1600") == [5, 12, 19])
    #expect(matching("iso:<200") == [1, 8, 15, 22])
    #expect(matching("iso:<=200") == [1, 2, 8, 9, 15, 16, 22, 23])
}

@Test func apertureAndFocalLengthCompareNumbers() {
    // f/2.8 and f/1.8 are under 4; the macro shoots at f/8.
    #expect(matching("f:<4") == [1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 19, 20, 22, 23])
    #expect(matching("f:>=8") == [3, 6, 9, 12, 15, 18, 21])
    // 50 mm: the 50mm F1.8 and the zoom at 50 (IMG_0007, IMG_0019).
    #expect(matching("mm:50") == [2, 5, 7, 8, 11, 14, 17, 19, 20, 23])
    #expect(matching("mm:>70") == [3, 6, 9, 12, 15, 18, 21])
}

@Test func keywordFieldIgnoresCase() {
    #expect(matching("keyword:beach") == [1, 2, 3, 4, 13, 14])
    #expect(matching("keyword:BEACH") == [1, 2, 3, 4, 13, 14])
    #expect(matching("keyword:su") == [3, 4, 5, 6, 20])
}

@Test func quotedPhraseIsOneToken() {
    #expect(matching("\"24-70mm F2.8\"") == [1, 4, 7, 10, 13, 16, 19, 22])
    #expect(matching("lens:\"50mm F1.8\"") == [2, 5, 8, 11, 14, 17, 20, 23])
    // Reversed, the phrase is in no lens; as two plain words both are.
    #expect(matching("\"F2.8 24-70mm\"").isEmpty)
    #expect(matching("F2.8 24-70mm") == [1, 4, 7, 10, 13, 16, 19, 22])
}

@Test func everyTokenMustMatch() {
    // Sunset is on 3-6; the FX-2 shoots the even ones.
    #expect(matching("sunset fx-2") == [4, 6])
    #expect(matching("iso:>1600 beach") == [13, 14])
    #expect(matching("lens:50 keyword:summer") == [20])
}

@Test func badFieldsArePlainText() {
    #expect(matching("iso:abc").isEmpty)
    #expect(matching("foo:bar").isEmpty)
    #expect(matching("mm:>").isEmpty)
}

@Test func plainTextMatchesTheName() {
    #expect(matching("img_0003") == [3])
    #expect(matching("IMG_002") == [20, 21, 22, 23, 24])
    #expect(matching("fixture optics").count == 23)
}

@Test func plainTextMatchesTitleAndCaption() {
    let photo = PhotoItem(name: "IMG_9", captureDate: .distantPast, color: Color3(0.5, 0.5, 0.5),
                          title: "Harbour at dawn", caption: "Low tide")
    #expect(PhotoSearch("harbour").matches(photo))
    #expect(PhotoSearch("title:dawn").matches(photo))
    #expect(PhotoSearch("caption:tide").matches(photo))
    #expect(!PhotoSearch("caption:harbour").matches(photo))
}

@Test func suggestionsOfferCameraValues() {
    var catalog = LibraryCatalog()
    catalog.load(cameras)
    #expect(catalog.searchSuggestions(prefix: "50").contains("lens:\"50mm F1.8\""))
    #expect(catalog.searchSuggestions(prefix: "", limit: 3).count <= 3)
    #expect(catalog.searchSuggestions(prefix: "zzz").isEmpty)
}
