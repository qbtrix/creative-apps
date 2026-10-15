// LibraryKeysTests.swift: the single-key table and the `library.controls`
// JSON (spine SP-13). Runs on Linux and macOS.
@testable import LibraryModel
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Test func digitsAreRatingsAndLettersNameTheirAction() {
    for stars in 0...5 {
        #expect(LibraryKey(character: Character(String(stars))) == .rating(stars))
    }
    #expect(LibraryKey(character: "3") == .rating(3))
    #expect(LibraryKey(character: "P") == .pick && LibraryKey(character: "p") == .pick)
    #expect(LibraryKey(character: "x") == .reject && LibraryKey(character: "X") == .reject)
    #expect(LibraryKey(character: "u") == .unflag && LibraryKey(character: "U") == .unflag)
    #expect(LibraryKey(character: "r") == .crop && LibraryKey(character: "R") == .crop)
    #expect(LibraryKey(character: "g") == .grid && LibraryKey(character: "G") == .grid)
    #expect(LibraryKey(character: "7") == nil)
    #expect(LibraryKey(character: "q") == nil)
    #expect(LibraryKey(character: " ") == nil)
}

@Test func specialKeysConfirmAndJumpToTheEnds() {
    #expect(LibraryKey(special: .returnKey) == .confirm)
    #expect(LibraryKey(special: .home) == .first)
    #expect(LibraryKey(special: .end) == .last)
}

@Test func controlsJSONRoundTripsWithTheReason() throws {
    let controls = [
        LibraryControlState(id: "library.import", enabled: false, reason: "Import isn't connected yet (import)."),
        LibraryControlState(id: "library.grid", enabled: true),
    ]
    let json = controlsJSON(controls)
    struct Document: Decodable { var controls: [LibraryControlState] }
    let decoded = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
    #expect(decoded.controls.map(\.id) == ["library.grid", "library.import"])
    #expect(decoded.controls.first { $0.id == "library.grid" }?.enabled == true)
    #expect(decoded.controls.first { $0.id == "library.grid" }?.reason == nil)
    let disabled = decoded.controls.first { $0.id == "library.import" }
    #expect(disabled?.enabled == false)
    #expect(disabled?.reason == "Import isn't connected yet (import).")
}
