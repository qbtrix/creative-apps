// PasteboardFolderTests.swift (clipboard-interop CB-2, turned on by CB-4): the CLI's pasteboard is a folder with
// one file per type; every item kind round-trips through it, a write replaces what was there, and a file the
// folder didn't write is ignored.
import Foundation
import SuiteModel
import Testing

@Suite struct PasteboardFolderTests {
    let coder = SuitePasteboardCoding()

    /// A fresh, empty folder under the temporary directory.
    func scratch() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pasteboard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// One of each item kind the suite copies.
    var everyKind: [SuiteClipItem] {
        [.appLayers(.designLayers, Data(#"{"layers":[]}"#.utf8)), .appLayers(.flareLayers, Data([0, 1, 2])),
         .vector(svg: "<svg/>", name: "Art"), .image(png: Data([0x89, 0x50, 0x4E, 0x47]), pixelWidth: 1, pixelHeight: 1),
         .text("hello")]
    }

    /// Each item kind's representations come back with the same types and bytes, in order.
    @Test(.disabled("waits on CB-4"))
    func everyItemKindRoundTrips() throws {
        let folder = PasteboardFolder(try scratch())
        for item in everyKind {
            let reps = coder.representations(of: item)
            try folder.write(reps)
            #expect(try folder.read() == reps, "\(item) lost a type on the round trip")
        }
    }

    /// Mutation `.writeReplaces`: a second write leaves only its own items.
    @Test(.disabled("waits on CB-4"))
    func aWriteReplacesWhatWasThere() throws {
        let folder = PasteboardFolder(try scratch())
        try folder.write([TypedData(type: .png, data: Data([1])), TypedData(type: .svg, data: Data("<svg/>".utf8))])
        let text = [TypedData(type: .plainText, data: Data("after".utf8))]
        try folder.write(text)
        #expect(try folder.read() == text)
    }

    /// Mutation `.typeFromManifest`: an own type with no file extension of its own keeps its full type id.
    @Test(.disabled("waits on CB-4"))
    func anOwnTypeKeepsItsIDNotItsExtension() throws {
        let folder = PasteboardFolder(try scratch())
        let own = [TypedData(type: .flareLayers, data: Data([7])), TypedData(type: .designLayers, data: Data([8]))]
        try folder.write(own)
        #expect(try folder.read().map(\.type) == [.flareLayers, .designLayers])
    }

    /// A file someone dropped into the folder by hand is not on the pasteboard; an empty folder reads as nothing.
    @Test(.disabled("waits on CB-4"))
    func anUnknownFileIsIgnored() throws {
        let url = try scratch()
        let folder = PasteboardFolder(url)
        #expect(try folder.read().isEmpty)
        let png = [TypedData(type: .png, data: Data([0x89, 0x50]))]
        try folder.write(png)
        try Data("stray".utf8).write(to: url.appendingPathComponent("notes.txt"))
        #expect(try folder.read() == png)
    }
}
