// DesignKeyCommandTests.swift: Design's key commands (one-document OD-8) through its catalog, as the afterglow CLI and
// MCP run them. keyframe.set, .remove, .move and .set-easing each record one undo step named their title and leave the
// rest pose alone; the last three are off with "Set a key first." on a still file. time.sample reads the node as the
// canvas shows it at a frame, parent offsets included; time.playhead moves the shown frame and records nothing. A
// keyed file keeps its keys through a headless save and reopen. Linux-safe.
@testable import DesignModel
import Foundation
import SuiteKernel
import Testing

@Suite struct DesignKeyCommandTests {
    @discardableResult
    static func run(_ id: String, _ params: [String: JSONValue], on w: inout DesignWorkspace) throws -> CommandOutcome {
        try DesignWorkspace.catalog.run(id, params: .object(params), on: &w)
    }
    static func key(_ property: String = "x", _ frame: Int, _ value: Double) -> [String: JSONValue] {
        ["node": .string("node-2"), "property": .string(property), "frame": .number(Double(frame)), "value": .number(value)]
    }
    static func at(_ property: String = "x", _ frame: Int) -> [String: JSONValue] {
        ["node": .string("node-2"), "property": .string(property), "frame": .number(Double(frame))]
    }
    /// time.sample's x, y and opacity for node-2 at `frame`.
    static func sample(_ w: inout DesignWorkspace, at frame: Int) throws -> [Double] {
        let result = try run("time.sample", ["node": .string("node-2"), "frame": .number(Double(frame))], on: &w).result
        guard case .object(let f) = result else { return [] }
        return ["x", "y", "opacity"].compactMap { if case .number(let n)? = f[$0] { n } else { nil } }
    }
    static func track(_ w: DesignWorkspace, _ property: DesignKeyProperty = .x) -> [Keyframe] {
        w.findNode("node-2")?.time?.tracks[property] ?? []
    }

    @Test func setWritesKeysAtTheirFramesAndSampleReadsBetween() throws {
        var w = DesignFixtures.cards
        let first = try Self.run("keyframe.set", Self.key(0, 100), on: &w)
        try Self.run("keyframe.set", Self.key(60, 160), on: &w)
        #expect(first.undoStep == "Set Key")
        #expect(Self.track(w).map(\.frame) == [0, 60] && w.findNode("node-2")?.frame.x == 100, "keys added; rest pose kept")
        #expect(try Self.sample(&w, at: 30) == [130, 100, 1])
        try Self.run("keyframe.set", Self.key(60, 200), on: &w)
        #expect(Self.track(w).map(\.value) == [100, 200], "a key already at the frame takes the new value")
        w.undo()
        #expect(Self.track(w).map(\.value) == [100, 160], "each set is its own step")
    }

    @Test func removeMoveAndEasingEditOneKey() throws {
        var w = DesignFixtures.cards
        try Self.run("keyframe.set", Self.key(0, 100), on: &w)
        try Self.run("keyframe.set", Self.key(60, 160), on: &w)
        try Self.run("keyframe.set", Self.key(120, 100), on: &w)
        let moved = try Self.run("keyframe.move", Self.at(60).merging(["to": .number(90)]) { a, _ in a }, on: &w)
        #expect(moved.undoStep == "Move Key" && Self.track(w).map(\.frame) == [0, 90, 120])
        #expect(throws: CatalogError.self) { try Self.run("keyframe.move", Self.at(90).merging(["to": .number(120)]) { a, _ in a }, on: &w) }
        let eased = try Self.run("keyframe.set-easing", Self.at(0).merging(["easing": .string("hold")]) { a, _ in a }, on: &w)
        #expect(eased.undoStep == "Set Easing" && Self.track(w).first?.easing == .hold)
        #expect(try Self.sample(&w, at: 45).first == 100, "hold keeps frame 0's value until the next key")
        let removed = try Self.run("keyframe.remove", Self.at(90), on: &w)
        #expect(removed.undoStep == "Remove Key" && Self.track(w).map(\.frame) == [0, 120])
        #expect(throws: CatalogError.self) { try Self.run("keyframe.remove", Self.at(90), on: &w) }
        w.undo()
        #expect(Self.track(w).map(\.frame) == [0, 90, 120], "undo puts the removed key back")
    }

    @Test func keyEditsAreOffOnAStillFile() {
        let still = DesignFixtures.cards
        for id in ["keyframe.remove", "keyframe.move", "keyframe.set-easing"] {
            #expect(DesignWorkspace.catalog.availability(id, on: still).why == "Set a key first.", "\(id)")
            #expect(DesignWorkspace.catalog.availability(id, on: DesignFixtures.animated(1)).why == nil, "\(id)")
        }
        #expect(DesignWorkspace.catalog.availability("keyframe.set", on: still).why == nil)
    }

    @Test func sampleReadsTheShownTreeWithItsParentsOffset() throws {
        var w = DesignFixtures.animated(50)
        let shown = try Self.sample(&w, at: 60)
        #expect(shown.count == 3 && abs(shown[0] - 47) < 0.01 && abs(shown[1] - 40) < 0.01 && abs(shown[2] - 0.65) < 0.01, "\(shown)")
        #expect(try Self.sample(&w, at: 0) == [30, 30, 1])
    }

    @Test func playheadMovesTheShownFrameAndRecordsNothing() throws {
        var w = DesignFixtures.animated(50)
        let bytes = try w.fileData()
        let outcome = try Self.run("time.playhead", ["frame": .number(60)], on: &w)
        #expect(w.playhead == 60 && outcome.undoStep == nil && !w.canUndo && (try w.fileData()) == bytes)
        try Self.run("time.playhead", ["frame": .number(100_000)], on: &w)
        #expect(w.playhead == w.time.durationFrames - 1, "past the end lands on the last frame")
        try Self.run("time.playhead", ["frame": .null], on: &w)
        #expect(w.playhead == nil)
    }

    @Test func keysSurviveAHeadlessSaveAndReopen() throws {
        var doc = try DesignHeadless.new(.object([:]))
        let rectangle = try #require(doc.workspace.pages.first?.nodes.first?.id)
        func run(_ id: String, _ params: [String: JSONValue]) throws -> JSONValue {
            try DesignHeadless.catalog.run(id, params: .object(params), on: &doc).result
        }
        for (frame, value) in [(0, 0.0), (60, 100.0)] {
            _ = try run("keyframe.set", ["node": .string(rectangle), "property": .string("x"), "frame": .number(Double(frame)), "value": .number(value)])
        }
        let sample: [String: JSONValue] = ["node": .string(rectangle), "frame": .number(30)]
        let before = try run("time.sample", sample)
        doc = try DesignHeadless.open(try doc.save(), name: "keyed.design")
        #expect(try run("time.sample", sample) == before)
        guard case .object(let f) = before else { Issue.record("no sample"); return }
        #expect(f["x"] == .number(50))
    }
}
