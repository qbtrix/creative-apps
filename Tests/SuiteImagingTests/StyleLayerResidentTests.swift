// StyleLayerResidentTests.swift (layer-styles HY-7): uploads per content, unstyled fallbacks, the layer's window.
import CoreRaster
import CoreRender
import SuiteImaging
import Testing

@Suite struct StyleLayerResidentTests {
    let resident = StyleLayerResident<String>(dispatcher: RenderDispatcher(preferred: nil, fallback: CPUBackend()))
    static func glow(_ opacity: Double = 0.75) -> LayerStyle {
        LayerStyle(effects: [StyleEffect(kind: .outerGlow, isEnabled: true, blendMode: .screen, opacity: opacity,
                                         parameters: .glow(StyleGlow(color: .white, spread: 0, size: 10)))], fillOpacity: 1)
    }
    static func layer() throws -> PixelBuffer {
        var buffer = try PixelBuffer(width: 4, height: 3)
        try buffer.setPixel(x: 0, y: 0, RGBA(r: 1, g: 0, b: 0, a: 1))
        return buffer
    }
    /// A draw that pads the layer by 2 on each side and marks the layer's own top-left red.
    func padded(_ style: LayerStyle, _ layer: RenderSurface) throws -> RenderSurface {
        var out = try PixelBuffer(width: layer.width + 4, height: layer.height + 4)
        try out.setPixel(x: 2, y: 2, RGBA(r: 1, g: 0, b: 0, a: 1))
        return try resident.dispatcher.surface(out)
    }

    @Test func styleOnlyStepUploadsNothing() throws {
        for (content, opacity) in [("a", 0.75), ("a", 0.5), ("a", 0.75), ("b", 0.75)] {
            resident.finish(try resident.step(content: content, pixels: { try Self.layer() }, style: Self.glow(opacity), draw: padded))
        }
        #expect(resident.uploads == 2)
    }

    @Test func throwingDrawShowsTheLayerUnstyled() throws {
        let step = try resident.step(content: "a", pixels: { try Self.layer() }, style: Self.glow()) { _, _ in throw ImagingError.notBuilt("LS-9") }
        guard case .unstyled(let surface) = step else { Issue.record("expected unstyled, got \(step)"); return }
        #expect(try resident.dispatcher.read(surface) == (try Self.layer()))
    }

    @Test func noStyleSkipsTheDraw() throws {
        var draws = 0
        for style in [nil, LayerStyle.none] {
            let step = try resident.step(content: "a", pixels: { try Self.layer() }, style: style) { draws += 1; return $1 }
            if case .styled = step { Issue.record("expected unstyled, got \(step)") }
        }
        #expect(draws == 0)
    }

    @Test func styledResultIsCutToTheLayerWindow() throws {
        let step = try resident.step(content: "a", pixels: { try Self.layer() }, style: Self.glow(), draw: padded)
        defer { resident.finish(step) }
        guard case .styled(let surface) = step else { Issue.record("expected styled, got \(step)"); return }
        #expect(try resident.dispatcher.read(surface) == (try Self.layer()))
        let clamped = StyleLayerResident<String>.window(styled: (2, 2), layer: (4, 3))
        #expect([clamped.x, clamped.y, clamped.width, clamped.height] == [0, 0, 2, 2])
    }
}
