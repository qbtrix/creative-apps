// FlareStageParityRasterTests.swift: the PNG frames draw a keyed fill colour and a shape morph as the SVG export
// writes them, because the stage list comes from FlareCore's sampled render list. A square keyed red to blue and
// grown from 30...70 to 10...90 over 24 frames: red at frame 0, purple at 12, and at 24 the grown square covers a
// point the frame-0 square leaves white. macOS only.
#if canImport(CoreGraphics)
import FlareCore
import FlareModel
import SuiteUI
import Testing

@testable import FlareApp

@Suite struct FlareStageParityRasterTests {
    static func square(_ lo: Double, _ hi: Double) -> FlarePath {
        FlarePath(polyline: [Point(x: lo, y: lo), Point(x: hi, y: lo), Point(x: hi, y: hi), Point(x: lo, y: hi)],
                  closed: true)
    }

    static var document: Document {
        let red = FlareColor(r: 1, g: 0, b: 0), blue = FlareColor(r: 0, g: 0, b: 1)
        var layer = Layer(id: "box", name: "Box", shapes: [FlareShape(points: [], fill: .solid(red), path: square(30, 70))])
        layer.colorTracks[TrackTarget.fill(shape: 0).key] = [ColorKeyframe(frame: 0, value: red), ColorKeyframe(frame: 24, value: blue)]
        layer.shapeTracks = [ShapeTrack(shapeIndex: 0, keys: [PathKeyframe(frame: 0, path: square(30, 70)),
                                                              PathKeyframe(frame: 24, path: square(10, 90))])]
        return Document(scenes: [FlareScene(id: "s", name: "S", width: 100, height: 100, layers: [layer])])
    }

    func pixel(at frame: Int, x: Int, y: Int) throws -> [Int] {
        let list = LiveStage().drawList(Self.document, sceneID: "s", frame: frame, editing: nil)
        let image = try #require(RGBAImage(png: try StageRasterizer().png(list, scale: 1, transparent: false)))
        let at = (y * image.width + x) * 4
        guard at >= 0, at + 4 <= image.bytes.count else { return [] }
        return image.bytes[at..<at + 4].map(Int.init)
    }

    @Test func pngFramesDrawTheKeyedColour() throws {
        #expect(try pixel(at: 0, x: 50, y: 50) == [255, 0, 0, 255])
        let mid = try pixel(at: 12, x: 50, y: 50)
        #expect(mid.count == 4 && abs(mid[0] - 128) <= 2 && mid[1] == 0 && abs(mid[2] - 128) <= 2, "\(mid)")
        #expect(try pixel(at: 24, x: 50, y: 50) == [0, 0, 255, 255])
    }

    @Test func pngFramesDrawTheMorph() throws {
        #expect(try pixel(at: 0, x: 20, y: 50) == [255, 255, 255, 255])
        #expect(try pixel(at: 24, x: 20, y: 50) == [0, 0, 255, 255])
    }
}
#endif
