// FlareCommandPathTests.swift (command-state CS-11): the catalog command each of Flare's bare controls runs once
// CS-12 wires it. Every id is in the catalog and the ledger with a params schema and runs headless: the recovery
// alert's Restore (the recovered bytes) and Discard, the New Animation sheet's Create (its preset, size, rate, length
// and background), the timeline's Add Label and Remove Label, and its context menu's Select All Keys, Delete
// Keyframe, Insert Frame and Remove Frame. Each sheet's values reach the run, and each command says why it is off.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteKernel
import Testing
@testable import FlareModel

struct FlareCommandPathTests {
    /// A control, the id it must run and the params it sends.
    struct Control: Sendable, CustomStringConvertible {
        let name, id: String
        let params: JSONValue
        var description: String { name }
    }

    static let recovered = String(decoding: (try? FlareFormat.encode(FlareFixtures.bounce)) ?? Data(), as: UTF8.self)
    static let created: JSONValue = .object(["preset": .string("Square"), "width": .number(640), "height": .number(480),
                                             "fps": .number(12), "durationFrames": .number(36), "background": .string("#FF0000")])

    static let controls = [
        Control(name: "FlareRecovery Restore", id: "recovery.restore", params: .object(["data": .string(recovered)])),
        Control(name: "FlareRecovery Discard", id: "recovery.discard", params: .object([:])),
        Control(name: "FlareNewSheet Create", id: "file.new", params: created),
        Control(name: "FlareTimelineEdit Add Label", id: "frame.label", params: .object(["name": .string("Intro")])),
        Control(name: "FlareTimelineEdit Remove Label", id: "frame.label", params: .object([:])),
        Control(name: "FlareTimelineEdit Select All Keys", id: "timeline.select-all-keys", params: .object([:])),
        Control(name: "FlareTimelineEdit Delete Keyframe", id: "timeline.delete-keys", params: .object([:])),
        Control(name: "FlareTimelineEdit Insert Frame", id: "timeline.insert-frames", params: .object(["count": .number(1)])),
        Control(name: "FlareTimelineEdit Remove Frame", id: "timeline.remove-frames", params: .object(["count": .number(1)])),
    ]

    /// Bounce, saved with a label "Start" at frame 10, the playhead there and Ball's key at 12 selected.
    static func fixture() -> FlareWorkspace {
        var ws = FlareWorkspace(services: .built)
        ws.load(FlareFixtures.bounce)
        ws.setCurrentFrame(10)
        ws.setLabel("Start")
        if let save = ws.saveData() { ws.didSave(save, named: "Bounce.flare") }
        ws.selectKey(KeyRef(layerID: "ball", property: nil, frame: 12), extending: false)
        return ws
    }

    static func ballX(_ ws: FlareWorkspace) -> [Int] {
        ws.ownerLayers?.first { $0.id == "ball" }?.tracks["x"]?.map(\.frame) ?? []
    }

    @Test(arguments: controls) func idIsCataloguedAndLedgered(_ control: Control) throws {
        let spec = try #require(FlareWorkspace.catalog.spec(control.id), "\(control.id) is in Flare's catalog")
        #expect(spec.params.validate(control.params).isEmpty, "the control's params fit \(control.id)'s schema")
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/flare.txt")
        let ledger = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(ledger.contains(control.id), "\(control.id) is in the ledger")
    }

    @Test(arguments: controls) func runsHeadless(_ control: Control) {
        var ws = Self.fixture()
        #expect(!ws.isDirty)
        #expect(throws: Never.self) { _ = try FlareWorkspace.catalog.run(control.id, params: control.params, on: &ws) }
    }

    /// Each control's values reach the run.
    @Test func paramsReachRun() throws {
        var ws = Self.fixture()
        _ = try FlareWorkspace.catalog.run("file.new", params: Self.created, on: &ws)
        let scene = try #require(ws.selectedScene)
        #expect((scene.width, scene.height, scene.fps, scene.durationFrames) == (640, 480, 12, 36))
        #expect(scene.background == FlareColor(r: 1, g: 0, b: 0) && !ws.isDirty)
        let bad: JSONValue = .object(["background": .string("#GG0000")])
        #expect(throws: CatalogError.failed(id: "file.new", message: "Pick a valid background color.")) {
            _ = try FlareWorkspace.catalog.run("file.new", params: bad, on: &ws)
        }

        _ = try FlareWorkspace.catalog.run("recovery.restore", params: Self.controls[0].params, on: &ws)
        #expect(ws.document == FlareFixtures.bounce && ws.isDirty && ws.title == "Untitled")

        ws = Self.fixture()
        _ = try FlareWorkspace.catalog.run("frame.label", params: .object(["name": .string("Intro")]), on: &ws)
        #expect(ws.timelineLabels[10] == "Intro" && ws.undoActionName != nil)
        _ = try FlareWorkspace.catalog.run("frame.label", params: .object([:]), on: &ws)
        #expect(ws.timelineLabels[10] == nil)
        #expect(throws: CatalogError.failed(id: "frame.label", message: "No label at the playhead.")) {
            _ = try FlareWorkspace.catalog.run("frame.label", params: .object([:]), on: &ws)
        }
        #expect(throws: CatalogError.failed(id: "frame.label", message: "Name the label first.")) {
            _ = try FlareWorkspace.catalog.run("frame.label", params: .object(["name": .string(" ")]), on: &ws)
        }

        ws = Self.fixture()
        _ = try FlareWorkspace.catalog.run("timeline.insert-frames", params: .object(["count": .number(2)]), on: &ws)
        #expect(Self.ballX(ws) == [0, 14, 26, 38, 49])
        _ = try FlareWorkspace.catalog.run("timeline.remove-frames", params: .object(["count": .number(3)]), on: &ws)
        #expect(Self.ballX(ws) == [0, 11, 23, 35, 46])
        _ = try FlareWorkspace.catalog.run("timeline.delete-keys", params: .object([:]), on: &ws)
        #expect(Self.ballX(ws) == [0, 23, 35, 46] && ws.undoActionName == "Undo Delete Keyframe")
        _ = try FlareWorkspace.catalog.run("timeline.select-all-keys", params: .object([:]), on: &ws)
        #expect(!ws.selectedKeys.isEmpty)
    }

    /// Without an animation each says so; Delete Keyframe needs a key, and Restore and Discard keep unsaved work.
    @Test func reasonWhenUnavailable() {
        let none = FlareWorkspace(services: .built)
        for id in ["frame.label", "timeline.insert-frames", "timeline.remove-frames", "timeline.delete-keys"] {
            #expect(FlareWorkspace.catalog.availability(id, on: none).why != nil, "\(id) without an animation")
        }
        #expect(FlareWorkspace.catalog.availability("frame.label", on: none).why == "Open an animation to label its frames.")
        #expect(FlareWorkspace.catalog.availability("timeline.insert-frames", on: none).why == "Open an animation to edit its timeline.")
        var ws = Self.fixture()
        for control in Self.controls {
            #expect(FlareWorkspace.catalog.availability(control.id, on: ws).why == nil, "\(control.id) runs on a saved animation")
        }
        ws.selectKey(KeyRef(layerID: "ball", property: nil, frame: 12), extending: true)
        #expect(FlareWorkspace.catalog.availability("timeline.delete-keys", on: ws).why == FlareWorkspace.selectKeyFirst)
        ws.setLabel("Edited")
        for id in ["recovery.restore", "recovery.discard"] {
            #expect(FlareWorkspace.catalog.availability(id, on: ws).why == FlareWorkspace.recoveryKeepsEdits, "\(id) while dirty")
        }
    }
}
