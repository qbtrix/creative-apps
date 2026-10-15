// BoxGestureMathTests.swift: ST-7 of live-stage (#740), the box math moved out of FakeShapes into BoxGestureMath with
// no behavior change. The expected values are what FakeShapes.boxResult returned before the move, on bounce with
// Shadow turned 30° (the oblique path, which reads the draw list) and Ball square (the plain path).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import FlareModel
import Testing

private typealias Values = [String: [String: Double]]

/// Pre-move `FakeShapes.boxResult` for a scale of each handle 0...7 dragged by (50, 20), then a 15° rotate.
private let recorded: [Values] = [
    ["ball": ["scaleX": 0.42185857971668667, "scaleY": 0.9499084759433466, "x": 97.3442426084994, "y": 118.49725427830037],
     "shadow": ["scaleX": 0.5081405913135493, "scaleY": 0.9499084759433466, "x": 130.8825779934104, "y": 93.08484851315882]],
    ["ball": ["scaleX": 1.0, "scaleY": 0.9499084759433466, "x": 80.0, "y": 118.49725427830037],
     "shadow": ["scaleX": 0.9499084759433466, "scaleY": 0.9499084759433466, "x": 3.1135381615478224, "y": 23.50640668396568]],
    ["ball": ["scaleX": 1.5781414202833133, "scaleY": 0.9499084759433466, "x": 112.6557573915006, "y": 118.49725427830037],
     "shadow": ["scaleX": 1.4754897531275923, "scaleY": 0.9499084759433466, "x": -105.78623261040389, "y": -59.272644472553]],
    ["ball": ["scaleX": 1.5781414202833133, "scaleY": 1.0, "x": 112.6557573915006, "y": 100.0],
     "shadow": ["scaleX": 1.5781414202833133, "scaleY": 1.5781414202833133, "x": -13.595556231164494, "y": -255.73562053372416]],
    ["ball": ["scaleX": 1.5781414202833133, "scaleY": 1.0500915240566535, "x": 112.6557573915006, "y": 101.5027457216996],
     "shadow": ["scaleX": 1.4918594086864507, "scaleY": 1.0500915240566535, "x": -91.08477027782425, "y": -55.41413312796686]],
    ["ball": ["scaleX": 1.0, "scaleY": 1.0500915240566535, "x": 80.0, "y": 101.5027457216996],
     "shadow": ["scaleX": 1.0500915240566535, "scaleY": 1.0500915240566535, "x": -3.113538161547851, "y": -3.5064066839657357]],
    ["ball": ["scaleX": 0.42185857971668667, "scaleY": 1.0500915240566535, "x": 97.3442426084994, "y": 101.5027457216996],
     "shadow": ["scaleX": 0.5245102468724077, "scaleY": 1.0500915240566535, "x": 143.64845293586984, "y": 58.24939338518317]],
    ["ball": ["scaleX": 0.42185857971668667, "scaleY": 1.0, "x": 97.3442426084994, "y": 100.0],
     "shadow": ["scaleX": 0.42185857971668667, "scaleY": 0.42185857971668667, "x": 63.595556231164466, "y": 255.73562053372422]],
    ["ball": ["rotation": 15.0, "x": 123.45344739644403, "y": 109.20744358877215],
     "shadow": ["rotation": 45.0, "x": 72.06128580357064, "y": -8.090662648336377]],
]

private func turnedBounce() throws -> (document: Document, box: Rect) {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try engine.perform(SetKeyframe(owner: .scene("scene-1"), layerID: "shadow", property: "rotation",
                                   keyframe: Keyframe(frame: 0, value: 30)))
    let picked = ["shadow", "ball"].map { StageAddress(owner: .scene("scene-1"), layerID: $0, item: .shape(0)) }
    let box = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: picked))
    return (engine.document, box)
}

private func gesture(_ i: Int, on box: Rect) -> BoxGesture {
    guard i < 8 else { return .rotate(degrees: 15) }
    let grip = BoxGestureMath.handle(i, on: box)
    return .scale(handle: i, to: Point(x: grip.x + 50, y: grip.y + 20))
}

@Test(arguments: 0..<9)
func boxGestureMathMatchesThePreMoveFakeShapes(_ i: Int) throws {
    let (document, box) = try turnedBounce()
    let list = FakeStage().drawList(document, sceneID: "scene-1", frame: 0, editing: nil)
    let moved = BoxGestureMath.result(gesture(i, on: box), layers: ["shadow", "ball"], document: document,
                                      sceneID: "scene-1", frame: 0, box: box, list: list)
    #expect(moved == recorded[i], "gesture \(i)")
    let fake = FakeShapes().boxResult(gesture(i, on: box), layers: ["shadow", "ball"], document: document,
                                      sceneID: "scene-1", frame: 0, box: box)
    #expect(fake == recorded[i], "gesture \(i)")
}

@Test(arguments: 0..<8)
func fakeShapesHandleForwardsToBoxGestureMath(_ h: Int) throws {
    let box = try turnedBounce().box
    #expect(FakeShapes.handle(h, on: box) == BoxGestureMath.handle(h, on: box))
}

@Test func noLiveSourceNamesAFake() throws {
    let live = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Sources/FlareModel/Live")
    let files = try FileManager.default.contentsOfDirectory(atPath: live.path).filter { $0.hasSuffix(".swift") }
    #expect(files.contains("BoxGestureMath.swift"))
    for file in files {
        let text = try String(contentsOf: live.appendingPathComponent(file), encoding: .utf8)
        #expect(!text.contains("FakeStage"), "\(file) names FakeStage")
        #expect(!text.contains("FixtureEdit"), "\(file) names FixtureEdit")
    }
}
