// FlareRotationStepTests.swift: #2238 (J7 step 5). Ball's Rotation, animated at 0 (keys at 0 and 47), keyed at 20 by
// a drag and then stepped +1, +1, +10 as separate scrubs, reads each stepped value at 20 and keeps its keys at
// 0, 20 and 47; the playhead stays on 20. The journey's 28.888… is 30 · 26/27, Rotation read at frame 21: the arrow
// moved the playhead (Animate > Step Frame) instead of stepping the bar, so the Model's own sum is pinned here.
import FlareCore
@testable import FlareModel
import Testing

private func rotation(_ w: FlareWorkspace) -> Double? {
    w.animatedProperties.first { $0.name == "rotation" }?.value
}

private func rotationKeys(_ w: FlareWorkspace) -> [Int] {
    w.ownerLayers?.first { $0.id == "ball" }?.tracks["rotation"]?.map(\.frame) ?? []
}

@Test func steppingAKeyedRotationAtTwentyAddsEachStepThere() {
    var w = FlareWorkspace(services: .built)
    w.load(FlareFixtures.bounce)
    w.selectLayer("ball")
    w.toggleAnimated("rotation")
    w.currentFrame = 20
    w.setProperty("rotation", to: 30, dragStart: rotation(w) ?? 0)
    w.endPropertyScrub()
    #expect(rotation(w) == 30)
    for (step, total) in [(1.0, 31.0), (1, 32), (10, 42)] {
        let start = rotation(w) ?? 0
        w.setProperty("rotation", to: start + step, dragStart: start)
        w.endPropertyScrub()
        #expect(rotation(w) == total)
    }
    #expect(w.currentFrame == 20 && rotationKeys(w) == [0, 20, 47])
}
