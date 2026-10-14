// HaloLayerOpacityClampTests.swift: a layer's opacity stays in 0...1 (NaN
// becomes 1) after any assignment, not only in init, so an out-of-range value
// never makes the layer vanish from the rendered frame (#456), and a decoded
// file can't carry one either. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import HaloModel
import Testing

private let white = HaloLayerColor(red: 1, green: 1, blue: 1)
private let black = HaloLayerColor(red: 0, green: 0, blue: 0)

private func solid(_ id: String, _ color: HaloLayerColor) -> HaloLayer {
    HaloLayer(id: id, name: id, kind: .solid, inFrame: 0, outFrame: 30, color: color)
}

/// A 40 x 20 composition (10 x 5 at preview size); `layers` top first.
private func comp(_ layers: [HaloLayer]) -> HaloComposition {
    HaloComposition(id: "c", name: "C", width: 40, height: 20, framesPerSecond: 30, durationFrames: 30, layers: layers)
}

@Test(arguments: [(-0.5, 0.0), (1.7, 1.0), (.nan, 1.0), (.infinity, 1.0), (-.infinity, 0.0), (0.25, 0.25)])
func opacityAssignedAfterInitIsClamped(assigned: Double, stored: Double) throws {
    var top = solid("top", white)
    top.opacity = assigned
    #expect(top.opacity == stored)

    // The frame draws white over black at the clamped opacity, mixed in linear light.
    let frame = comp([top, solid("bottom", black)]).renderFrame(at: 0)
    let pixel = try #require(try frame?.pixels.pixel(x: 0, y: 0))
    #expect(abs(Double(pixel.r) - stored) < 0.0001 && pixel.a == 1)
}

@Test func compoundAssignmentPastOneStaysOpaque() {
    var layer = solid("a", white)
    layer.opacity += 0.5
    #expect(layer.opacity == 1)
    layer.opacity -= 3
    #expect(layer.opacity == 0)
}

@Test(arguments: [("3", 1.0), ("-2", 0.0), ("\"nan\"", 1.0), ("\"inf\"", 1.0), ("0.25", 0.25)])
func decodedOpacityIsClamped(opacity: String, stored: Double) throws {
    let json = """
        {"id":"a","name":"A","kind":"solid","inFrame":0,"outFrame":30,
         "color":{"red":1,"green":1,"blue":1},"opacity":\(opacity),"blendMode":"normal"}
        """
    let decoder = JSONDecoder()
    decoder.nonConformingFloatDecodingStrategy = .convertFromString(
        positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
    let layer = try decoder.decode(HaloLayer.self, from: Data(json.utf8))
    #expect(layer.opacity == stored)
}
