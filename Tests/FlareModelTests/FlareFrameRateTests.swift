// FlareFrameRateTests.swift (frame-rates FR-9, test first): a Flare scene runs at the kernel's exact rates.
// `oldFilesUnchanged`: a file from before fractional rates (`"fps": 24`, no `frameRate`) opens at 24/1 and re-saves
// byte for byte. `lottieExactFr`: a 23.976 scene's Lottie says `fr` 23.976 (24000/1001), not 24. `durationRounds`: its
// `op` is the scene's length in frames, a duration in seconds turned into frames by `FrameRate.frames(forDuration:)`
// (round, half up; 10 s at 23.976 is 240, where a floor gives 239). Each test sets the rate through the catalog's
// `scene.set-frame-rate` and reads it back through `FlareFrameRate+Kernel.swift` (FR-10).
import FlareCore
import Foundation
import FlareModel
import SuiteKernel
import Testing

/// A `.flare` file written before rates were fractions: one 24 fps scene, 48 frames, no `frameRate`.
private let oldFile = Data("""
    {"format": "flare", "version": 1, "document": {"scenes": [
      {"id": "scene-1", "name": "Old", "fps": 24, "durationFrames": 48, "layers": []}
    ], "symbols": []}}
    """.utf8)

/// 23.976: the kernel's list entry, never a typed literal.
private let ntsc24 = FrameRate.common.first { $0.numerator == 24000 && $0.denominator == 1001 } ?? FrameRate(whole: 0)

/// A new Web-preset document (550 x 400) set to `rate`, `seconds` long in whole frames by the kernel's rounding rule.
private func scene(at rate: FrameRate, seconds: Double) throws -> FlareHeadless {
    var workspace = FlareWorkspace(services: .built)
    workspace.newDocument(NewDocumentSpec(preset: .web))
    let id = try #require(workspace.selectedSceneID)
    let params = JSONValue.object(["num": .number(Double(rate.numerator)), "den": .number(Double(rate.denominator)),
                                   "seconds": .number(seconds)])
    _ = try FlareWorkspace.catalog.run("scene.set-frame-rate", params: params, on: &workspace)
    #expect(workspace.layerError == nil)
    #expect(workspace.scenes.first { $0.id == id }?.frameRate == rate)
    return FlareHeadless(workspace: workspace)
}

/// The Lottie root's top-level fields for the selected scene.
private func lottieRoot(_ doc: FlareHeadless) throws -> [String: Any] {
    let file = try #require(try doc.export("lottie", options: .null).first)
    return try #require(try JSONSerialization.jsonObject(with: file.data) as? [String: Any])
}

@Suite struct FlareFrameRateTests {
    @Test func oldFilesUnchanged() throws {
        let doc = try FlareHeadless.open(oldFile, name: "old.flare")
        let scene = try #require(doc.workspace.selectedScene)
        #expect(scene.frameRate == FrameRate(whole: 24))
        #expect(scene.fps == 24 && scene.durationFrames == 48)
        let saved = try doc.save()
        #expect(!String(decoding: saved, as: UTF8.self).contains("frameRate"))
        let reopened = try FlareHeadless.open(saved, name: "old.flare")
        #expect(reopened.workspace.document == doc.workspace.document)
        #expect(try reopened.save() == saved)
    }

    @Test func lottieExactFr() throws {
        #expect(ntsc24.description == "23.976 fps")
        let root = try lottieRoot(try scene(at: ntsc24, seconds: 10))
        let fr = try #require(root["fr"] as? Double)
        #expect(abs(fr - 24000.0 / 1001.0) < 1e-9)
        #expect((fr * 1000).rounded() == 23_976)
    }

    @Test func durationRounds() throws {
        #expect(ntsc24.frames(forDuration: 10) == 240)
        let doc = try scene(at: ntsc24, seconds: 10)
        #expect(doc.workspace.selectedScene?.durationFrames == 240)
        let root = try lottieRoot(doc)
        #expect(root["ip"] as? Int == 0)
        #expect(root["op"] as? Int == ntsc24.frames(forDuration: 10))
    }
}
