// DesignFileTimeTests.swift: a document with time through the file flow (one-document OD-14). Keys set through the
// catalog, as the inspector's key button and the CLI set them, save to a file on disk and reopen with every key,
// their easing and the document's rate and length; the reopened file resaves to the bytes it opened from, and the
// timeline shows on open with the rest pose at frame 0 and the keyed pose at 60. An autosave copy written to a real
// RecoveryFolder recovers the same keys and time, dirty and with no location. A still file stays byte for byte
// version 1 through a playhead change and through a key that is undone; a key marks the file dirty, a playhead
// change doesn't. The fixture fakes' codec keeps the time too, writing the bytes it always wrote for a still file.
// Linux-safe.
@testable import DesignModel
import Foundation
import SuiteKernel
import SuiteModel
import Testing

@Suite struct DesignFileTimeTests {
    static func run(_ id: String, _ params: [String: JSONValue], on w: inout DesignWorkspace) throws {
        _ = try DesignWorkspace.catalog.run(id, params: .object(params), on: &w)
    }
    static func key(_ property: String, _ frame: Int, _ value: Double) -> [String: JSONValue] {
        ["node": .string("node-2"), "property": .string(property), "frame": .number(Double(frame)), "value": .number(value)]
    }
    /// time.sample's x, y and opacity for node-2 at `frame`.
    static func sample(_ w: inout DesignWorkspace, at frame: Int) throws -> JSONValue {
        try DesignWorkspace.catalog.run("time.sample", params: .object(["node": .string("node-2"), "frame": .number(Double(frame))]), on: &w).result
    }
    static func folder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("od14-\(UUID().uuidString)", isDirectory: true)
    }

    /// `cards` with node-2 keyed on x (100 to 400, eased out) and opacity (1 to 0.4) over 0...60, at 30 fps for 90 frames.
    static func keyed() throws -> DesignWorkspace {
        var w = DesignFixtures.cards
        for (property, frame, value) in [("x", 0, 100.0), ("x", 60, 400), ("opacity", 0, 1), ("opacity", 60, 0.4)] {
            try run("keyframe.set", key(property, frame, value), on: &w)
        }
        try run("keyframe.set-easing", ["node": .string("node-2"), "property": .string("x"), "frame": .number(0), "easing": .string("easeOut")], on: &w)
        w.time = DesignDocumentTime(rate: FrameRate(whole: 30), durationFrames: 90)
        return w
    }

    @Test func aKeyedFileSavesAndReopensWithEveryKeyAndItsTime() throws {
        var w = try Self.keyed()
        #expect(w.isDirty)
        let dir = Self.folder()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("keyed.design")
        try w.fileData().write(to: url)
        w.didSave(to: url)
        #expect(!w.isDirty)

        let bytes = try Data(contentsOf: url)
        #expect(try LiveFiling.probeVersion(bytes) == 2)
        var reopened = DesignWorkspace()
        try reopened.open(bytes, at: url)
        #expect(reopened.pages == w.pages)
        #expect(reopened.time == w.time)
        #expect(reopened.findNode("node-2")?.time?.tracks[.x]?.first?.easing == .easeOut)
        #expect(reopened.showsTimeline && reopened.playhead == nil)
        #expect(!reopened.isDirty && !reopened.canUndo && reopened.documentURL == url)
        #expect(try Self.sample(&reopened, at: 0) == .object(["x": .number(100), "y": .number(100), "opacity": .number(1)]))
        #expect(try Self.sample(&reopened, at: 60) == .object(["x": .number(400), "y": .number(100), "opacity": .number(0.4)]))
        #expect(try reopened.fileData() == bytes, "a reopened keyed file resaves to other bytes")
    }

    @Test func anAutosaveCopyRecoversEveryKeyAndItsTime() throws {
        let w = try Self.keyed()
        let dir = Self.folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recovery = RecoveryFolder(store: FileStore(folder: dir.path), ext: "design")
        try recovery.write(try w.recoveryBytes(), window: "w1", name: "Keyed", at: 1)
        let left = try recovery.leftBehind()
        let item = try #require(left.first)
        #expect(left.count == 1)
        let recovered = try DesignWorkspace.recovered(from: item.data, name: item.name)
        #expect(recovered.pages == w.pages && recovered.time == w.time)
        #expect(recovered.isDirty && recovered.documentURL == nil)
        var restored = DesignFixtures.cards
        try restored.restoreRecovered(from: item.data, name: item.name)
        #expect(restored.pages == w.pages && restored.time == w.time)
        #expect(try recovered.fileData() == w.fileData())
    }

    @Test func aStillFileStaysVersion1ByteForByte() throws {
        var w = DesignWorkspace()
        try w.open(Data(DesignNodeTimeTests.cardsVersion1.utf8))
        try Self.run("time.playhead", ["frame": .number(40)], on: &w)
        #expect(w.playhead == 40 && !w.isDirty && !w.canUndo, "a playhead change is an edit")
        #expect(String(decoding: try w.fileData(), as: UTF8.self) == DesignNodeTimeTests.cardsVersion1)
        try Self.run("keyframe.set", Self.key("x", 40, 120), on: &w)
        #expect(w.isDirty && w.canUndo, "a key isn't an edit")
        #expect(try LiveFiling.probeVersion(try w.fileData()) == 2)
        w.undo()
        #expect(w.isStill)
        #expect(String(decoding: try w.fileData(), as: UTF8.self) == DesignNodeTimeTests.cardsVersion1)
    }

    @Test func theFixtureFakesKeepTheTime() throws {
        var w = try Self.keyed()
        w.useServices(.fake)
        var reopened = DesignWorkspace()
        reopened.useServices(.fake)
        try reopened.open(try w.fileData())
        #expect(reopened.pages == w.pages && reopened.time == w.time)

        var still = DesignFixtures.cards
        still.useServices(.fake)
        #expect(try still.fileData() == JSONEncoder().encode(still.pages), "a still file's fake bytes changed")
    }
}
