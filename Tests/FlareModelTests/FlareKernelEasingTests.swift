// FlareKernelEasingTests.swift: AE-f1 of adopt-kernel-easing (#1937). Flare's presets are `EasePreset`, its curve is
// `EaseCurve`, a summary key is the kernel's `.all`, and a key move, remove or frame edit lands where `KeyRules` puts it.
import FlareCore
import FlareModel
import SuiteKernel
import Testing

private let scene = LayerOwner.scene("scene-1"), bounce = FlareFixtures.bounce
private func ball(_ document: Document) -> [String: [Int]] {
    (document.layers(of: scene)?.first { $0.id == "ball" }?.tracks ?? [:]).mapValues { $0.map(\.frame) }
}
private func tracks() -> [String: [Keyframe]] { bounce.layers(of: scene)?.first { $0.id == "ball" }?.tracks ?? [:] }
private func key(_ property: String?, _ frame: Int) -> FlareModel.KeyRef { .init(layerID: "ball", property: property, frame: frame) }

@Test func presetsAndCurveAreTheKernels() {
    #expect(EasingPreset.allCases == EasePreset.allCases && LiveEasing().presets == FakeEasing().presets)
    let point = Point(x: 1.4, y: -0.7)
    for easing in EasePreset.allCases.map(\.easing) + [.cubicBezier(x1: 0.3, y1: -0.4, x2: 0.8, y2: 1.6)] {
        let flare = EasingCurve.handles(of: easing)
        #expect([flare.first, flare.second] == EaseCurve.handles(of: easing) ?? [Point(x: 0, y: 0), Point(x: 1, y: 1)])
        #expect(EasingCurve.moving(easing, .first, to: point) == EaseCurve.moving(0, to: point, in: easing))
        #expect(EasingCurve.moving(easing, .second, to: point) == EaseCurve.moving(1, to: point, in: easing))
        #expect(EasingCurve.moving(easing, .second, to: Point(x: .nan, y: 0)) == nil)
        // Flare's editor draws nothing for fewer than two points, where the kernel gives (0, 0) alone.
        #expect(EasingCurve.samples(of: easing, count: 1).isEmpty)
        for count in [-1, 0, 1, 2, 5, 64, Int.max] {
            let kernel = EaseCurve.samples(of: easing, count: count)
            if count >= 2 { #expect(EasingCurve.samples(of: easing, count: count) == kernel) }
            #expect(LiveEasing().curve(easing, count: count) == kernel && FakeEasing().curve(easing, count: count) == kernel)
        }
    }
}

@Test func keysAndSegmentsAreTheKernels() throws {
    #expect(key(nil, 24).kernel == SuiteKernel.KeyRef(layerID: "ball", track: .all, frame: 24))
    #expect(FlareModel.KeyRef(key("x", 12).kernel) == key("x", 12) && FlareModel.KeyRef(key(nil, 24).kernel) == key(nil, 24))
    let row = EasingSegment(property: "x", startFrame: 12, endFrame: 24), segment = row.segment(on: "ball", easing: .easeIn)
    #expect(segment == Segment(key: key("x", 12).kernel, endFrame: 24, easing: .easeIn) && EasingSegment(segment) == row)
    var live = CommandEngine(document: bounce), fake = CommandEngine(document: bounce)
    try LiveEasing().setEasing(.easeOut, at: key(nil, 12), owner: scene, coalesceKey: nil, in: &live)
    try FakeEasing().setEasing(.easeOut, at: key(nil, 12), owner: scene, coalesceKey: nil, in: &fake)
    #expect(live.document == fake.document && live.document.layers(of: scene)?.first { $0.id == "ball" }?.tracks.values
        .allSatisfy { $0.first { $0.frame == 12 }?.easing == .easeOut } == true)
}

@Test func movesRemovesAndFrameEditsLandWhereKeyRulesPutThem() throws {
    for (keys, delta) in [([key("x", 24)], 5), ([key(nil, 24), key(nil, 36)], -2)] {
        var expected = keys[0].property == nil ? tracks() : ["x": tracks()["x"] ?? []]
        try KeyRules.moveKeys(&expected, Set(keys.map(\.frame)), by: delta, clampedTo: 0...47)
        for editor in [LiveKeyframes() as any KeyframeEditing, FakeKeyframes()] {
            var engine = CommandEngine(document: bounce)
            try editor.moveKeys(Set(keys), by: delta, owner: scene, coalesceKey: nil, in: &engine)
            #expect(expected.allSatisfy { ball(engine.document)[$0.key] == $0.value.map(\.frame) })
        }
    }
    // Flare's insert moves the key at its frame too, so it is the kernel's insert after the frame before.
    var removed = tracks(), inserted = tracks(), dropped = tracks()
    for name in Array(removed.keys) {
        KeyRules.removeKeys(&removed[name, default: []], name == "x" ? [12, 24] : [24], leaving: .singleStays)
        KeyRules.insertFrames(&inserted[name, default: []], 2, at: 46)
        KeyRules.removeFrames(&dropped[name, default: []], 3, at: 12)
    }
    for editor in [LiveKeyframes() as any KeyframeEditing, FakeKeyframes()] {
        var engine = CommandEngine(document: bounce)
        try editor.removeKeys([key("x", 12), key(nil, 24)], owner: scene, in: &engine)
        #expect(ball(engine.document) == removed.mapValues { $0.map(\.frame) })
        engine = CommandEngine(document: bounce)
        try editor.insertFrames(2, at: 47, layerIDs: ["ball"], owner: scene, in: &engine)
        #expect(ball(engine.document) == inserted.mapValues { $0.map(\.frame) } && engine.document.scenes.first?.durationFrames == 50)
        engine = CommandEngine(document: bounce)
        try editor.removeFrames(3, at: 12, layerIDs: ["ball"], owner: scene, in: &engine)
        #expect(ball(engine.document) == dropped.mapValues { $0.map(\.frame) })
    }
}

@Test func aRefusedMoveStaysRefused() {
    var live = CommandEngine(document: bounce), fake = CommandEngine(document: bounce)
    #expect(throws: CommandError.frameOccupied(property: "x", frame: 36)) {
        try LiveKeyframes().moveKeys([key("x", 24)], by: 12, owner: scene, coalesceKey: "drag", in: &live)
    }
    #expect(throws: CommandError.invalidDocument("A key can't move before frame 0.")) {
        try LiveKeyframes().moveKeys([key("y", 12)], by: -13, owner: scene, coalesceKey: nil, in: &live)
    }
    // A key past the range wins over one landing on a key that stays: 47 -> 59 refuses before 12 -> 24 collides.
    #expect(throws: CommandError.invalidFrame(59)) {
        try FakeKeyframes().moveKeys([key("x", 12), key("x", 47)], by: 12, owner: scene, coalesceKey: nil, in: &fake)
    }
    #expect(throws: CommandError.invalidDocument("A key can't move past the scene's last frame.")) {
        try LiveKeyframes().moveKeys([key("x", 12), key(nil, 47)], by: 12, owner: scene, coalesceKey: nil, in: &live)
    }
    #expect(live.document == bounce && fake.document == bounce && !live.canUndo && !fake.canUndo)
}
