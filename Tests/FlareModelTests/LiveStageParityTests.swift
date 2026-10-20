// LiveStageParityTests.swift: the live stage (and so hit testing and PNG frames) draws what the SVG export writes at
// every frame: a fill colour key, a trim key and a shape morph, all sampled once by FlareCore's render list
// (`Layer.sampledShape`). Before that, the stage drew the shape's static values while SVG and Lottie animated them.
// Runs on Linux and macOS; the pixel checks are in AppSnapshotTests/RasterizerTests.swift.
import FlareCore
@testable import FlareModel
import Testing

enum ParityFixture {
    static let red = FlareColor(r: 1, g: 0, b: 0), blue = FlareColor(r: 0, g: 0, b: 1)
    static func square(_ lo: Double, _ hi: Double) -> FlarePath {
        FlarePath(polyline: [Point(x: lo, y: lo), Point(x: hi, y: lo), Point(x: hi, y: hi), Point(x: lo, y: hi)],
                  closed: true)
    }

    /// One square on a 100 × 100 white scene: its fill keyed red to blue, its stroke trimmed from nothing to the
    /// whole outline, and its path morphed from 30...70 to 10...90, all linear over frames 0...24.
    static var document: Document {
        let shape = FlareShape(points: [], fill: .solid(red), path: square(30, 70), stroke: Stroke(color: red, width: 4))
        var layer = Layer(id: "box", name: "Box", shapes: [shape])
        layer.colorTracks[TrackTarget.fill(shape: 0).key] = [ColorKeyframe(frame: 0, value: red), ColorKeyframe(frame: 24, value: blue)]
        layer.tracks[Layer.trackKey(trimEndOf: 0)] = [Keyframe(frame: 0, value: 0), Keyframe(frame: 24, value: 1)]
        layer.shapeTracks = [ShapeTrack(shapeIndex: 0, keys: [PathKeyframe(frame: 0, path: square(30, 70)),
                                                              PathKeyframe(frame: 24, path: square(10, 90))])]
        return Document(scenes: [FlareScene(id: "s", name: "S", width: 100, height: 100, layers: [layer])])
    }
}

@Test(arguments: [0, 6, 12, 18, 24])
func theStageDrawsTheSampledShapeAtEveryFrame(_ frame: Int) throws {
    let document = ParityFixture.document
    let layer = try #require(document.scenes.first?.layers.first)
    let item = try #require(LiveStage().drawList(document, sceneID: "s", frame: frame, editing: nil).items.first)
    let want = layer.sampledShape(0, at: Double(frame))
    #expect(item.fill == want.fill && item.stroke == want.stroke && item.path == want.outline)
    // The SVG export writes the same fill and path at that frame.
    let svg = try SVGExporter.export(scene: try #require(document.scenes.first), frame: Double(frame))
    if case .solid(let color)? = item.fill {
        let hex = "#" + [color.r, color.g, color.b].map {
            let byte = String(Int((min(max($0, 0), 1) * 255).rounded()), radix: 16)
            return byte.count == 1 ? "0" + byte : byte
        }.joined()
        #expect(svg.contains("fill=\"\(hex)\""), "\(hex) at \(frame)")
    }
    #expect(svg.contains("d=\"\(try SVGExporter.pathData(item.path))\""))
}

@Test func midTweenIsHalfwayInColourTrimAndShape() throws {
    let item = try #require(LiveStage().drawList(ParityFixture.document, sceneID: "s", frame: 12, editing: nil).items.first)
    #expect(item.fill == .solid(FlareColor(r: 0.5, g: 0, b: 0.5)))
    #expect(item.stroke?.trim?.end == 0.5)
    #expect(item.path.bounds == Rect(minX: 20, minY: 20, maxX: 80, maxY: 80))
}

/// Hit testing reads the same render list: at frame 24 a click inside the grown square but outside the frame-0 one
/// hits the box.
@Test func hitTestingFollowsTheMorph() throws {
    var workspace = FlareWorkspace(launch: FlareLaunch(arguments: []))
    workspace.load(ParityFixture.document)
    let probe = Point(x: 15, y: 50)
    workspace.setCurrentFrame(0)
    #expect(workspace.hit(at: probe, stageScale: 1) == nil)
    workspace.setCurrentFrame(24)
    #expect(workspace.hit(at: probe, stageScale: 1)?.layerID == "box")
}
