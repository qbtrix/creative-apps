// LiveKeyframesTests.swift: KY-5's acceptance (docs/blueprints/flare/features/live-keys.md): `LiveKeyframes.rows` and
// `labels` equal `FakeKeyframes` on `bounce` and `character` (every scene, and the symbol "wave"), the hand's row inside
// "wave" lists keys 0, 12 and 23, and a scene with no layers gives no rows.
import FlareCore
import FlareModel
import Testing

private let live = LiveKeyframes()
private let fake = FakeKeyframes()

@Test(arguments: ["bounce", "character"])
func rowsAndLabelsMatchFake(_ name: String) throws {
    let document = try #require(FlareFixtures.named(name))
    #expect(!document.scenes.isEmpty)
    for scene in document.scenes {
        let owner = LayerOwner.scene(scene.id)
        #expect(live.rows(document, owner: owner) == fake.rows(document, owner: owner), "\(name) \(scene.id)")
        #expect(live.labels(document, sceneID: scene.id) == fake.labels(document, sceneID: scene.id), "\(name) \(scene.id)")
    }
    for symbol in document.symbols {
        let owner = LayerOwner.symbol(symbol.id)
        #expect(live.rows(document, owner: owner) == fake.rows(document, owner: owner), "\(name) \(symbol.id)")
    }
}

@Test func waveHandRowListsItsKeys() throws {
    let rows = live.rows(FlareFixtures.character, owner: .symbol("wave"))
    let hand = try #require(rows.first { $0.layerID == "hand" })
    #expect(hand.keyFrames == [0, 12, 23])
    #expect(hand.segments == [0...12, 12...23])
}

@Test func sceneWithNoLayersGivesNoRows() {
    #expect(live.rows(FlareFixtures.empty, owner: .scene("scene-1")) == [])
    #expect(live.rows(FlareFixtures.empty, owner: .scene("missing")) == [])
    #expect(live.labels(FlareFixtures.empty, sceneID: "missing") == [:])
}

@Test func easedSegmentTakesFirstTrackByNameThatTweensOut() {
    let layer = Layer(id: "l", name: "L", tracks: [
        "x": [Keyframe(frame: 0, value: 0, easing: .easeIn), Keyframe(frame: 10, value: 1, easing: .easeOut)],
        "a": [Keyframe(frame: 0, value: 0), Keyframe(frame: 5, value: 1, easing: .hold), Keyframe(frame: 10, value: 2, easing: .easeIn)],
        "b": [Keyframe(frame: 0, value: 0, easing: .easeOut), Keyframe(frame: 5, value: 1)],
    ])
    let document = Document(scenes: [FlareScene(id: "s", name: "S", layers: [layer])])
    let rows = live.rows(document, owner: .scene("s"))
    #expect(rows == fake.rows(document, owner: .scene("s")))
    #expect(rows.first?.keyFrames == [0, 5, 10])
    #expect(rows.first?.easedSegments == [0: .easeOut, 5: .hold])
}
