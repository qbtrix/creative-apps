// FlareDocumentSetupTests.swift (document-setup DS-13, test first; DS-14 turns it on): Flare's document setup
// through SuiteKernel's `DocumentSetup` (FlareDocumentSetup+Kernel.swift). `verticalPreset`: the Vertical 9:16 preset
// reads back as 1080 × 1920 px at 30 fps through `document.read-settings`. `settingsKeepKeys`: Document Settings to
// 30 fps and 15 s on `bounce` makes 450 frames in one undo step, keeps every layer's keys, the size and a red
// background, and Undo brings the 48 frames at 24 back.
import FlareCore
import FlareModel
import SuiteKernel
import Testing

/// A fresh live workspace with `bounce` open.
private func bounce() -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .built)
    workspace.finishOpen(.success(FlareFixtures.bounce), named: "Bounce")
    return workspace
}

/// The rate `document.read-settings` answers, as numerator and denominator.
private func rate(_ reading: JSONValue) -> (Int, Int)? {
    guard case .object(let fields) = reading, case .object(let rate)? = fields["frameRate"],
          case .number(let num)? = rate["num"], case .number(let den)? = rate["den"] else { return nil }
    return (Int(num), Int(den))
}

@Suite struct FlareDocumentSetupTests {
    @Test func verticalPreset() throws {
        var workspace = FlareWorkspace(services: .built)
        _ = try FlareWorkspace.catalog.run("file.new", params: .object(["preset": .string("Vertical 9:16")]), on: &workspace)
        let reading = try FlareWorkspace.catalog.run("document.read-settings", params: .object([:]), on: &workspace).result
        guard case .object(let fields) = reading else { Issue.record("read-settings answered \(reading)"); return }
        #expect(fields["pixelWidth"] == .number(1080) && fields["pixelHeight"] == .number(1920))
        #expect(rate(reading).map { $0 == (30, 1) } == true)
        #expect(fields["duration"] == .number(5))
    }

    @Test func settingsKeepKeys() throws {
        var workspace = bounce()
        let red = FlareColor(r: 1, g: 0, b: 0)
        workspace.setSceneCanvas(width: 550, height: 400, background: red)
        let before = try #require(workspace.selectedScene)
        #expect(before.durationFrames == 48 && before.background == red)

        let params = JSONValue.object(["frameRate": .object(["num": .number(30), "den": .number(1)]), "duration": .number(15)])
        _ = try FlareWorkspace.catalog.run("document.set-settings", params: params, on: &workspace)
        #expect(workspace.layerError == nil)
        let after = try #require(workspace.selectedScene)
        #expect(after.durationFrames == 450, "15 s at 30 fps is 450 frames, not \(after.durationFrames)")
        #expect(after.frameRate == FrameRate(whole: 30))
        #expect(after.layers == before.layers, "Document Settings moved or dropped keys")
        #expect(after.width == 550 && after.height == 400)
        #expect(after.background == red, "Document Settings dropped the background")
        #expect(workspace.undoActionName == "Undo Document Settings")

        workspace.undo()
        #expect(workspace.selectedScene?.durationFrames == 48)
        #expect(workspace.selectedScene?.frameRate == FrameRate(whole: 24))
    }
}
