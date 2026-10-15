// ProjectFilesContractTests.swift: what every ProjectFiles promises (#209),
// run over the fake and the live type, which share one envelope
// (`HaloFileFormat`). Content validation is HF-5's and the live type's
// alone. Runs on Linux and macOS.
import Foundation
import HaloModel
import Testing

let projectFileses: [any ProjectFiles] = [FakeProjectFiles(), LiveProjectFiles()]

/// The 64 MiB limit both types share.
let projectFileLimit = 64 * 1024 * 1024

/// One byte over the 64 MiB limit, zero-filled; a global, so it is built
/// lazily and once.
let oversizedProjectFile = Data(count: projectFileLimit + 1)

@Test(arguments: projectFileses)
func fakeFilesRoundTripAndRefuse(files: any ProjectFiles) throws {
    let state = HaloDocumentState(compositions: [keyedPair()], selectedCompositionID: "c", nextCompositionNumber: 2)
    #expect(try files.decode(files.encode(state)) == state)
    #expect(throws: HaloFileError.notAHaloFile) { try files.decode(Data("not json".utf8)) }
    #expect(throws: HaloFileError.newerVersion(2)) { try files.decode(Data(#"{"format":"halo","version":2}"#.utf8)) }
    #expect(throws: HaloFileError.damaged("it has no project")) {
        try files.decode(Data(#"{"format":"halo","version":1}"#.utf8))
    }
}

@Test(arguments: projectFileses)
func encodeWritesTheEnvelopeWithSortedKeys(files: any ProjectFiles) throws {
    let text = String(decoding: try files.encode(HaloDocumentState()), as: UTF8.self)
    #expect(text.hasPrefix(#"{"format":"halo","project":"#))
    #expect(text.contains(#""version":1"#))
    #expect(text.hasSuffix(#""version":1}"#))
}

@Test(arguments: projectFileses)
func aFileOverTheLimitIsTooLarge(files: any ProjectFiles) {
    #expect(throws: HaloFileError.tooLarge) { try files.decode(oversizedProjectFile) }
}

@Test(arguments: projectFileses)
func aValidFilePaddedToExactlyTheLimitOpens(files: any ProjectFiles) throws {
    let state = try #require(HaloFixtures.project("keyed"))
    var data = try files.encode(state)
    data.append(Data(repeating: UInt8(ascii: " "), count: projectFileLimit - data.count))
    #expect(data.count == projectFileLimit)
    #expect(try files.decode(data) == state)
}

@Test(arguments: projectFileses)
func anotherFormatIsNotAHaloFile(files: any ProjectFiles) {
    #expect(throws: HaloFileError.notAHaloFile) { try files.decode(Data(#"{"format":"flare","version":1}"#.utf8)) }
}

@Test(arguments: projectFileses)
func aMissingFieldIsDamagedAndNamesWhere(files: any ProjectFiles) throws {
    let state = try #require(HaloFixtures.project("empty"))
    let text = String(decoding: try files.encode(state), as: UTF8.self)
    let broken = text.replacingOccurrences(of: #""name":"Comp 1","#, with: "")
    #expect(broken != text)
    #expect(throws: HaloFileError.damaged("the first composition is missing its name")) {
        try files.decode(Data(broken.utf8))
    }
}

/// HF-6: every fixture but `huge` (too slow to decode in a debug Linux
/// build) survives a round trip byte for byte and value for value.
@Test(arguments: projectFileses, HaloFixtures.names.filter { $0 != "huge" })
func roundTripEveryFixture(files: any ProjectFiles, name: String) throws {
    let fixture = try #require(HaloFixtures.project(name))
    let first = try files.encode(fixture)
    let decoded = try files.decode(first)
    #expect(decoded == fixture)
    #expect(try files.encode(decoded) == first)
}
