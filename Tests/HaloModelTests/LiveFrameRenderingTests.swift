// LiveFrameRenderingTests.swift: HF-2, the live renderer on a 40 x 20
// composition (#457): exact W3C blend values, a rotated solid's coverage, and
// shapes that match CoreRaster's ellipse mask, unrotated and rotated. Runs on
// Linux and macOS.
import CoreRaster
import FlareCore
import HaloModel
import Testing

private let red = HaloLayerColor(red: 1, green: 0, blue: 0)

private func item(_ kind: HaloLayerKind, _ bounds: HaloLayerRect, degrees: Double = 0) -> HaloDrawItem {
    // Rotated about the box's center, as an anchor at the center does.
    let cx = bounds.x + bounds.width / 2, cy = bounds.y + bounds.height / 2
    let m = HaloMatrix.translation(x: cx, y: cy) * HaloMatrix.rotation(degrees: degrees)
        * HaloMatrix.translation(x: -cx, y: -cy)
    return HaloDrawItem(
        layerID: "\(kind)", kind: kind, bounds: bounds, matrix: degrees == 0 ? .identity : m, opacity: 1,
        color: red, blendMode: .normal)
}

private func render(_ items: [HaloDrawItem]) throws -> PixelBuffer {
    try LiveFrameRendering().render(
        HaloDrawList(width: 40, height: 20, frame: 0, items: items), width: 40, height: 20, text: nil
    ).pixels
}

private let circleBox = HaloLayerRect(x: 10, y: 0, width: 20, height: 20)

@Test func aHalfRedSolidInMultiplyOverBlueGivesHalfBlue() throws {
    let blue = HaloLayerColor(red: 0, green: 0, blue: 1)
    let c = HaloComposition(id: "c", name: "C", width: 40, height: 20, framesPerSecond: 30, durationFrames: 30, layers: [
        HaloLayer(id: "top", name: "Top", kind: .solid, inFrame: 0, outFrame: 30, color: red, opacity: 0.5,
                  blendMode: .multiply),
        HaloLayer(id: "bottom", name: "Bottom", kind: .solid, inFrame: 0, outFrame: 30, color: blue),
    ])
    let pixels = try LiveFrameRendering().render(
        LiveFrameDrawing().drawList(c, at: 0), width: 40, height: 20, text: nil).pixels
    for y in 0..<20 {
        for x in 0..<40 {
            let p = try pixels.pixel(x: x, y: y)
            #expect(p.r == 0 && p.g == 0 && abs(p.b - 0.5) < 1e-6 && p.a == 1, "(\(x), \(y))")
        }
    }
}

@Test func aSolidRotated45DegreesHasPartialCoverageOnItsEdge() throws {
    let pixels = try render([item(.solid, HaloLayerRect(x: 15, y: 5, width: 10, height: 10), degrees: 45)])
    #expect(try pixels.pixel(x: 19, y: 9).a == 1)
    #expect(try pixels.pixel(x: 0, y: 0).a == 0)
    // The edge from the top vertex (20, 2.93) to the right one (27.07, 10) crosses pixel (23, 6).
    let edge = try pixels.pixel(x: 23, y: 6).a
    #expect(edge > 0 && edge < 1)
}

@Test func anUnrotatedShapeMatchesTheEllipseMask() throws {
    let pixels = try render([item(.shape, circleBox)])
    let mask = try Mask.ellipse(width: 40, height: 20, centerX: 20, centerY: 10, radiusX: 10, radiusY: 10)
    for y in 0..<20 {
        for x in 0..<40 {
            let c = try mask.coverage(x: x, y: y)
            #expect(try pixels.pixel(x: x, y: y) == RGBA(r: c, g: 0, b: 0, a: c), "(\(x), \(y))")
        }
    }
}

@Test func aRotatedCircleStaysWithinOnePixelOfTheEllipseMask() throws {
    let pixels = try render([item(.shape, circleBox, degrees: 30)])
    let mask = try Mask.ellipse(width: 40, height: 20, centerX: 20, centerY: 10, radiusX: 10, radiusY: 10)
    func onEdge(_ x: Int, _ y: Int) -> Bool {
        // Some pixel within one of (x, y) is partly covered by the true circle.
        (-1...1).contains { dy in
            (-1...1).contains { dx in
                guard let c = try? mask.coverage(x: x + dx, y: y + dy) else { return false }
                return c > 0 && c < 1
            }
        }
    }
    for y in 0..<20 {
        for x in 0..<40 {
            let diff = abs(try pixels.pixel(x: x, y: y).a - mask.coverage(x: x, y: y))
            #expect(diff < 1e-6 || onEdge(x, y), "(\(x), \(y)) is off by \(diff)")
        }
    }
}
