// FlareCatalogRealParamsTests.swift: the CLI's FlareCore commands on the shipped Bounce.flare (#5832). A command is
// unavailable only for what no params could change (no document, masks, not built); its own params decide the rest,
// so keyframe.set-easing on a real key runs, and keyframe.move refuses a frame outside the scene as a key drag does.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareCatalogRealParamsTests {
    let scene = LayerOwner.scene("scene-1")

    /// Bundle/Samples/Bounce.flare: scene-1 is 60 frames; layer-1 has x@0 and y@0, 30, 60.
    func bounce() throws -> FlareHeadless {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Bundle/Samples/Bounce.flare"))
        return try FlareHeadless.open(data, name: "Bounce.flare")
    }

    func move(to frame: Int) throws -> JSONValue {
        try JSONValue(encoding: MoveKeyframe(owner: scene, layerID: "layer-1", property: "x", from: 0, to: frame))
    }

    @Test func aKeyMoveOutsideTheSceneRefusesAndChangesNothing() throws {
        var doc = try bounce()
        let before = try doc.save()
        for (frame, why) in [(500, LiveKeyframes.pastSceneEnd), (60, LiveKeyframes.pastSceneEnd), (-1, LiveKeyframes.beforeFrameZero)] {
            #expect(throws: CatalogError.failed(id: "keyframe.move", message: why)) {
                try FlareHeadless.catalog.run("keyframe.move", params: try move(to: frame), on: &doc)
            }
            #expect(try doc.save() == before, "\(frame)")
        }
        _ = try FlareHeadless.catalog.run("keyframe.move", params: try move(to: 59), on: &doc)
        let x = doc.workspace.document?.layers(of: scene)?.first { $0.id == "layer-1" }?.tracks["x"]
        #expect(x?.map(\.frame) == [59])
    }

    @Test func setEasingOnARealKeyRuns() throws {
        var doc = try bounce()
        let params = try JSONValue(encoding: SetKeyframeEasing(owner: scene, layerID: "layer-1", property: "y", frame: 30, easing: .hold))
        #expect(FlareHeadless.catalog.availability("keyframe.set-easing", on: doc) == .available)
        _ = try FlareHeadless.catalog.run("keyframe.set-easing", params: params, on: &doc)
        let y = doc.workspace.document?.layers(of: scene)?.first { $0.id == "layer-1" }?.tracks["y"]
        #expect(y?.first { $0.frame == 30 }?.easing == .hold)
    }

    @Test func aKeyThatIsntThereRefusesWithTheEnginesSentence() throws {
        var doc = try bounce()
        let params = try JSONValue(encoding: SetKeyframeEasing(owner: scene, layerID: "layer-1", property: "y", frame: 7, easing: .hold))
        #expect(throws: CatalogError.self) { try FlareHeadless.catalog.run("keyframe.set-easing", params: params, on: &doc) }
        do { _ = try FlareHeadless.catalog.run("keyframe.set-easing", params: params, on: &doc) } catch let error as CatalogError {
            guard case .failed(_, let message) = error else { Issue.record("\(error) is not a refusal of its params"); return }
            #expect(!message.isEmpty)
        }
    }
}
