// DesignFilingTests.swift: the codec lives in LiveFiling and DesignFile calls it
// through `services.filing`. Every fixture encodes to the bytes DesignFile wrote
// before the move (`empty`'s file pinned as a literal, the others by length and
// an FNV-1a hash taken from those bytes) and decodes back to the same document
// (QD-V1); the four bad files of J16 give their reasons word for word; and a
// refused open leaves the workspace's pages as they were. Runs on Linux and
// macOS.
@testable import DesignModel
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite struct DesignFilingTests {
    /// `DesignFixtures.empty` as DesignFile wrote it before the codec moved.
    static let emptyFile = #"{"pages":[{"frameHeight":1024,"frameWidth":1440,"id":"page-1","name":"Page 1","nodes":[{"children":[],"cornerRadius":0,"fill":{"blue":255,"green":255,"red":255},"frame":{"height":1024,"width":1440,"x":0,"y":0},"id":"node-1","isHidden":false,"isLocked":false,"kind":"frame","name":"Desktop","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}}]}],"version":1}"#

    /// Each fixture's file before the move: its length and its 64-bit FNV-1a hash.
    static let pinned: [String: (count: Int, hash: UInt64)] = [
        "empty": (405, 0xffbd_889c_992b_0bed),
        "cards": (3131, 0xe8a2_c216_5a72_77f7),
        "two-pages": (3508, 0x3be3_b5ed_e882_a630),
        "crowd": (627_858, 0x1277_7ecb_0112_efbb),
        "stress": (1_572_481, 0x71ca_c38f_2635_356a),
    ]

    /// A rectangle node with `id`, in the file's own JSON.
    static func node(_ id: String) -> String {
        #"{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":80,"width":100,"x":100,"y":100},"id":""#
            + id + #"","isHidden":false,"isLocked":false,"kind":"rectangle","name":"A","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}}"#
    }

    /// The four bad files J16 opens, each with the error it must give and the alert's words.
    static let badFiles: [(name: String, data: Data, error: DesignFileError, reason: String)] = [
        ("not json", Data("This is not JSON.".utf8), .unreadable, "It is not a Design file."),
        ("version 99", Data(#"{"pages":[],"version":99}"#.utf8), .unsupportedVersion(99),
         "It was made by a newer version of Design (file version 99; this version opens up to 1)."
            + " Update Design to open it."),
        ("no pages", Data(#"{"pages":[],"version":1}"#.utf8), .noPages, "It has no pages."),
        ("node-2 twice", Data((#"{"pages":[{"frameHeight":100,"frameWidth":100,"id":"page-1","name":"Page 1","nodes":["#
            + node("node-2") + "," + node("node-2") + #"]}],"version":1}"#).utf8),
         .duplicateID("node-2"), "It is damaged: two of its layers share the id node-2."),
    ]

    static func fnv1a(_ data: Data) -> UInt64 {
        data.reduce(0xcbf2_9ce4_8422_2325 as UInt64) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01b3 }
    }

    static func fixture(_ name: String) throws -> DesignWorkspace {
        try #require(DesignFixtures.named(name))
    }

    @Test func emptyEncodesToTheLiteral() throws {
        let data = try LiveFiling().encode(DesignDocument(pages: Self.fixture("empty").pages))
        #expect(String(decoding: data, as: UTF8.self) == Self.emptyFile)
    }

    @Test(arguments: DesignFixtures.names)
    func everyFixtureEncodesToTodaysBytes(_ name: String) throws {
        let workspace = try Self.fixture(name)
        let data = try LiveFiling().encode(DesignDocument(pages: workspace.pages))
        let pin = try #require(Self.pinned[name])
        #expect(data.count == pin.count && Self.fnv1a(data) == pin.hash, "\(name)")
        #expect(try workspace.fileData() == data, "\(name)")
    }

    @Test(arguments: DesignFixtures.names)
    func roundTripIsStable(_ name: String) throws {
        let filing = LiveFiling()
        let document = DesignDocument(pages: try Self.fixture(name).pages)
        let data = try filing.encode(document)
        #expect(try filing.decode(data) == document)
        #expect(try filing.encode(filing.decode(data)) == data)
    }

    @Test func liveIsTheDefaultFiling() {
        #expect(DesignWorkspace().services.filing is LiveFiling)
    }

    @Test func badFilesGiveTheirReasons() {
        for bad in Self.badFiles {
            let thrown: DesignFileError?
            do { _ = try LiveFiling().decode(bad.data); thrown = nil } catch { thrown = error }
            #expect(thrown == bad.error, "\(bad.name)")
            #expect(thrown?.reason == bad.reason, "\(bad.name)")
        }
    }

    @Test func aRefusedOpenKeepsThePages() throws {
        var workspace = try Self.fixture("cards")
        workspace.gesture(.rectangle, pt(10, 10), pt(60, 60))
        let before = workspace
        for bad in Self.badFiles {
            let thrown: DesignFileError?
            do { try workspace.open(bad.data); thrown = nil } catch { thrown = error }
            #expect(thrown == bad.error, "\(bad.name)")
            #expect(workspace.pages == before.pages && workspace == before, "\(bad.name)")
        }
    }

    @Test func openReadsThroughTheFiling() throws {
        var workspace = DesignWorkspace()
        try workspace.open(Data(Self.emptyFile.utf8))
        #expect(workspace.pages == DesignFixtures.empty.pages)
        #expect(try workspace.fileData() == Data(Self.emptyFile.utf8))
    }
}
