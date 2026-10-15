// ProjectFilesContractTests.swift: what every ProjectFiles promises (#209),
// run over each conforming type in `projectFileses`; the live type joins by
// adding itself there. Runs on Linux and macOS.
import Foundation
import HaloModel
import Testing

let projectFileses: [any ProjectFiles] = [FakeProjectFiles()]

/// One byte over the 64 MiB limit, zero-filled; a global, so it is built
/// lazily and once.
let oversizedProjectFile = Data(count: 64 * 1024 * 1024 + 1)

@Test(arguments: projectFileses)
func filesRoundTripAndRefuse(files: any ProjectFiles) throws {
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
    #expect(text.hasSuffix(#""version":1}"#))
}

@Test(arguments: projectFileses)
func aFileOverTheLimitIsTooLarge(files: any ProjectFiles) {
    #expect(throws: HaloFileError.tooLarge) { try files.decode(oversizedProjectFile) }
}

@Test(arguments: projectFileses)
func anotherFormatIsNotAHaloFile(files: any ProjectFiles) {
    #expect(throws: HaloFileError.notAHaloFile) { try files.decode(Data(#"{"format":"flare","version":1}"#.utf8)) }
}
