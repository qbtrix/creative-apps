// LiveFilingVersionTests.swift: LiveFiling's version policy (one-document OD-3). A still document writes version 1,
// byte for byte as before; a document with keys or a set document time writes version 2 and reopens with its keys,
// their easing and the time; a reader that only knows version 1 refuses version 2 bytes with unsupportedVersion(2)
// instead of opening them with the keys gone; version 3 is refused; recovery copies go through the same codec.
// Linux-safe.
import Foundation
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct LiveFilingVersionTests {
    static func version(_ data: Data) throws -> Int { try LiveFiling.probeVersion(data) }

    static var keyed: DesignWorkspace {
        var workspace = DesignFixtures.animated(3)
        workspace.pages[0].nodes[0].children[0].time?.tracks[.x]?[0].easing = .easeOut
        return workspace
    }

    @Test func aStillDocumentWritesVersion1ByteForByte() throws {
        let data = try DesignFixtures.cards.fileData()
        #expect(try Self.version(data) == 1)
        #expect(String(decoding: data, as: UTF8.self) == DesignNodeTimeTests.cardsVersion1)
    }

    @Test func aKeyedDocumentWritesVersion2AndKeepsItsKeys() throws {
        let data = try Self.keyed.fileData()
        #expect(try Self.version(data) == 2)
        var reopened = DesignWorkspace()
        try reopened.open(data)
        #expect(reopened.pages == Self.keyed.pages)
        #expect(reopened.pages[0].nodes[0].children[0].time?.tracks[.x]?[0].easing == .easeOut)
    }

    @Test func aSetDocumentTimeAloneWritesVersion2() throws {
        var workspace = DesignFixtures.cards
        workspace.time = DesignDocumentTime(rate: FrameRate(whole: 30), durationFrames: 90)
        let data = try workspace.fileData()
        #expect(try Self.version(data) == 2)
        var reopened = DesignWorkspace()
        try reopened.open(data)
        #expect(reopened.time == workspace.time)
    }

    @Test func openingAStillFileResetsTheTime() throws {
        var workspace = DesignFixtures.cards
        workspace.time = DesignDocumentTime(rate: FrameRate(whole: 30), durationFrames: 90)
        try workspace.open(try DesignFixtures.cards.fileData())
        #expect(workspace.time == DesignDocumentTime())
    }

    @Test func aVersion1OnlyReaderRefusesVersion2() throws {
        let data = try Self.keyed.fileData()
        func versionOneReader(_ data: Data) throws(DesignFileError) {
            let version = try LiveFiling.probeVersion(data)
            guard version == 1 else { throw .unsupportedVersion(version) }
        }
        #expect(throws: DesignFileError.unsupportedVersion(2)) { try versionOneReader(data) }
    }

    @Test func version3IsRefused() throws {
        var text = String(decoding: try Self.keyed.fileData(), as: UTF8.self)
        text = text.replacingOccurrences(of: #""version":2"#, with: #""version":3"#)
        #expect(throws: DesignFileError.unsupportedVersion(3)) { try LiveFiling().decode(Data(text.utf8)) }
        let reason = DesignFileError.unsupportedVersion(3).reason
        #expect(reason.contains("file version 3; this version opens up to 2"))
    }

    @Test func recoveryKeepsTheKeysAndRefusesANewerCopy() throws {
        let bytes = try Self.keyed.recoveryBytes()
        #expect(try Self.version(bytes) == 2)
        #expect(try DesignWorkspace.recovered(from: bytes, name: nil).pages == Self.keyed.pages)
        let newer = Data(String(decoding: bytes, as: UTF8.self)
            .replacingOccurrences(of: #""version":2"#, with: #""version":3"#).utf8)
        #expect(throws: DesignFileError.unsupportedVersion(3)) { try DesignWorkspace.recovered(from: newer, name: nil) }
    }
}
