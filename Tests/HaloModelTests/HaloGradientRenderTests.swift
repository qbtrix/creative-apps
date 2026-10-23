// HaloGradientRenderTests.swift: gradient-fill HG-5, the renderer's checks,
// written first, on since HG-6 draws a layer's gradient. A radial
// white-to-black solid is white at its centre and black at its corners; the
// gradient moves with its layer; a shape's gradient stays inside its ellipse;
// a full-frame 1080p gradient's cost is reported. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloGradientRenderTests {
    /// White at the unit box's centre to black at its corners (radius √0.5,
    /// centre to corner).
    static let radial = Fill.radial(
        stops: [GradientStop(offset: 0, color: .white), GradientStop(offset: 1, color: FillColor(r: 0, g: 0, b: 0))],
        center: Point(x: 0.5, y: 0.5), radius: (0.5).squareRoot())

    /// A 2/255 tolerance on each channel.
    static let tolerance: Float = 2.0 / 255

    /// An odd size puts a pixel's center on the gradient's center.
    static func item(
        _ kind: HaloLayerKind = .solid, size: Double = 65, matrix: HaloMatrix = .identity
    ) -> HaloDrawItem {
        HaloDrawItem(
            layerID: "g", kind: kind, bounds: HaloLayerRect(x: 0, y: 0, width: size, height: size), matrix: matrix,
            opacity: 1, color: HaloLayerColor(red: 1, green: 0, blue: 0), blendMode: .normal, gradient: radial)
    }

    static func render(_ items: [HaloDrawItem], width: Int = 64, height: Int = 64) throws -> HaloRenderedFrame {
        try LiveFrameRendering().render(
            HaloDrawList(width: width, height: height, frame: 0, items: items), width: width, height: height, text: nil)
    }

    @Test func radialCentreAndCorner() throws {
        let pixels = try Self.render([Self.item()]).pixels
        let centre = try pixels.pixel(x: 32, y: 32), corner = try pixels.pixel(x: 0, y: 0)
        #expect(centre.r >= 1 - Self.tolerance && centre.g >= 1 - Self.tolerance && centre.b >= 1 - Self.tolerance)
        #expect(corner.r <= Self.tolerance && corner.g <= Self.tolerance && corner.b <= Self.tolerance)
        #expect(corner.a >= 1 - Self.tolerance)
    }

    @Test func gradientMovesWithLayer() throws {
        let moved = try Self.render([Self.item(size: 33, matrix: .translation(x: 32, y: 32))]).pixels
        let centre = try moved.pixel(x: 48, y: 48), layerCorner = try moved.pixel(x: 32, y: 32)
        #expect(centre.r >= 1 - Self.tolerance)
        #expect(layerCorner.r <= Self.tolerance && layerCorner.a >= 1 - Self.tolerance)
    }

    @Test func staysInsideEllipse() throws {
        let pixels = try Self.render([Self.item(.shape)]).pixels
        #expect(try pixels.pixel(x: 0, y: 0).a == 0)
        #expect(try pixels.pixel(x: 63, y: 63).a == 0)
        #expect(try pixels.pixel(x: 32, y: 32).r >= 1 - Self.tolerance)
    }

    @Test func fullFrameCost() throws {
        let solid = Self.item(size: 1920)
        let plain = HaloDrawItem(
            layerID: "p", kind: .solid, bounds: solid.bounds, matrix: .identity, opacity: 1, color: solid.color,
            blendMode: .normal)
        let clock = ContinuousClock()
        let base = try clock.measure { _ = try Self.render([plain], width: 1920, height: 1080) }
        let gradient = try clock.measure { _ = try Self.render([solid], width: 1920, height: 1080) }
        let added = gradient - base
        let ms = Double(added.components.seconds) * 1000 + Double(added.components.attoseconds) / 1e15
        print("HALO-GRADIENT-FRAME added \(ms) ms")
    }
}
