// HaloCompositionSettingsTests.swift (document-setup DS-11, slice DS-halo): Composition Settings… later, through
// the kernel's document.set-settings. A 10 s composition set to 15 s keeps every key at its time in one undo
// step; a size change anchored centre keeps layers centred; a navy background renders and saves, and an old
// white file opens and re-saves byte for byte. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import HaloModel
import SuiteKernel
import Testing

@Suite(.disabled("waits on DS-12")) struct HaloCompositionSettingsTests {
    static let set = "document.set-settings"

    /// A 1920 x 1080, 30 fps, 10 s composition: a boxed shape keyed on x at frames 30 and 270, and a centred one.
    static func keyed() -> HaloProject {
        var ball = HaloLayer(id: "comp-1-layer-1", name: "Ball", kind: .shape, inFrame: 0, outFrame: 300,
                             color: HaloLayerColor(red: 1, green: 1, blue: 1), rect: HaloLayerRect(x: 860, y: 440, width: 200, height: 200))
        ball.tracks["x"] = [HaloKeyframe(frame: 30, value: 960), HaloKeyframe(frame: 270, value: 1560)]
        let dot = HaloLayer(id: "comp-1-layer-2", name: "Dot", kind: .shape, inFrame: 0, outFrame: 300,
                            color: HaloLayerColor(red: 1, green: 0, blue: 0))
        let comp = HaloComposition(id: "comp-1", name: "Comp 1", width: 1920, height: 1080, framesPerSecond: 30,
                                   durationFrames: 300, layers: [ball, dot])
        var project = HaloProject(services: .fake)
        project.restore(HaloDocumentState(compositions: [comp], selectedCompositionID: "comp-1", nextCompositionNumber: 2, nextLayerNumber: 3))
        return project
    }

    static func run(_ project: inout HaloProject, _ fields: [String: JSONValue]) throws {
        _ = try HaloProject.catalog.run(set, params: .object(fields), on: &project)
    }

    @Test func longerCompositionKeepsKeyTimes() throws {
        var project = Self.keyed()
        try Self.run(&project, ["duration": .number(15)])
        let comp = try #require(project.selectedComposition)
        #expect(comp.durationFrames == 450 && comp.durationSeconds == 15)
        #expect(comp.layers.first?.tracks["x"]?.map(\.frame) == [30, 270], "a longer comp moved its keys")
        #expect(comp.layers.first?.outFrame == 450, "a layer to the old end doesn't reach the new end")
        #expect(project.history.undoTitle == "Undo Document Settings")
        project.undo()
        #expect(project.selectedComposition?.durationFrames == 300, "one undo didn't restore 10 s")

        var faster = Self.keyed()
        try Self.run(&faster, ["frameRate": .object(["num": .number(24), "den": .number(1)])])
        let retimed = try #require(faster.selectedComposition)
        #expect(retimed.frameRate == FrameRate(whole: 24) && retimed.durationFrames == 240, "a rate change didn't keep 10 s")
        #expect(retimed.layers.first?.tracks["x"]?.map(\.frame) == [24, 216], "keys left their seconds at 24 fps")
    }

    @Test func sizeChangeAnchoredCentreKeepsLayersCentred() throws {
        var project = Self.keyed()
        try Self.run(&project, ["width": .number(1280), "height": .number(720), "anchor": .string("center")])
        let comp = try #require(project.selectedComposition)
        #expect(comp.width == 1280 && comp.height == 720)
        let list = LiveFrameDrawing().drawList(comp, at: 30)
        for id in ["comp-1-layer-1", "comp-1-layer-2"] {
            let box = try #require(list.worldBox(of: id))
            #expect(abs(box.x + box.width / 2 - 640) < 1e-9 && abs(box.y + box.height / 2 - 360) < 1e-9, "\(id) left the centre")
        }
        #expect(comp.layers.first?.tracks["x"]?.map(\.value) == [640, 1240], "keyed x didn't move with the canvas")
    }

    @Test func navyBackgroundRendersAndSaves() throws {
        var project = Self.keyed()
        try Self.run(&project, ["background": .string("#1B2A4A"), "width": .number(64), "height": .number(36)])
        let comp = try #require(project.selectedComposition)
        #expect(comp.background == .color(hex: "#1B2A4A"))
        let frame = try LiveFrameRendering().render(LiveFrameDrawing().drawList(comp, at: 0), width: 64, height: 36, text: nil)
        let corner = Array(try frame.pixels.rgba8().prefix(4))
        for (got, want) in zip(corner, [0x1B, 0x2A, 0x4A, 0xFF] as [Int]) { #expect(abs(Int(got) - want) <= 2, "corner isn't navy: \(corner)") }

        let files = LiveProjectFiles()
        let saved = try files.encode(project.document)
        #expect(String(decoding: saved, as: UTF8.self).contains("\"background\":\"#1B2A4A\""))
        #expect(try files.decode(saved).compositions.first?.background == .color(hex: "#1B2A4A"))

        let old = try HaloFrameRateTests.oldFile(), state = try files.decode(old)
        #expect(state.compositions.first?.background == .white)
        let resaved = try files.encode(state)
        #expect(resaved == old, "an old white file changed bytes on save")
        #expect(!String(decoding: resaved, as: UTF8.self).contains("\"background\""), "white wrote a background")
    }
}
