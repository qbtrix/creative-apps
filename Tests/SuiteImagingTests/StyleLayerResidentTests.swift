// StyleLayerResidentTests.swift: the styled layer's residency (layer-styles
// HY-7). A style-only step uploads nothing, new content uploads once, a draw
// that throws (StyleRoute until LS-9) or no style shows the layer unstyled,
// and the styled result is cut back to the layer's own window. On the CPU
// backend, so it runs on Linux.
import CoreRaster
import CoreRender
import SuiteImaging
import Testing

@Suite struct StyleLayerResidentTests {
    let dispatcher = RenderDispatcher(preferred: nil, fallback: CPUBackend())
    static let glow = LayerStyle(effects: [StyleEffect(kind: .outerGlow, isEnabled: true, blendMode: .screen, opacity: 0.75,
                                                       parameters: .glow(StyleGlow(color: .white, spread: 0, size: 10)))],
                                 fillOpacity: 1)

    static func layer(_ width: Int = 4, _ height: Int = 3) throws -> PixelBuffer {
        var buffer = try PixelBuffer(width: width, height: height)
        try buffer.setPixel(x: 0, y: 0, RGBA(r: 1, g: 0, b: 0, a: 1))
        return buffer
    }

    /// A draw that pads the layer by 2 on each side and marks the layer's own top-left red.
    func padded(_ style: LayerStyle, _ layer: RenderSurface) throws -> RenderSurface {
        var out = try PixelBuffer(width: layer.width + 4, height: layer.height + 4)
        try out.setPixel(x: 2, y: 2, RGBA(r: 1, g: 0, b: 0, a: 1))
        return try dispatcher.surface(out)
    }

    @Test func styleOnlyStepUploadsNothing() throws {
        let resident = StyleLayerResident<String>(dispatcher: dispatcher)
        var bigger = Self.glow
        bigger.effects[0].opacity = 0.5
        for style in [Self.glow, bigger, Self.glow] {
            let step = try resident.step(content: "badge", pixels: { try Self.layer() }, style: style, draw: padded)
            resident.finish(step)
        }
        #expect(resident.uploads == 1)
    }

    @Test func newContentUploadsAgain() throws {
        let resident = StyleLayerResident<String>(dispatcher: dispatcher)
        for content in ["a", "a", "b"] {
            resident.finish(try resident.step(content: content, pixels: { try Self.layer() }, style: Self.glow, draw: padded))
        }
        #expect(resident.uploads == 2)
    }

    @Test func throwingDrawShowsTheLayerUnstyled() throws {
        let resident = StyleLayerResident<String>(dispatcher: dispatcher)
        let step = try resident.step(content: "a", pixels: { try Self.layer() }, style: Self.glow) { _, _ in
            throw ImagingError.notBuilt("layer-styles LS-9")
        }
        guard case .unstyled(let surface) = step else { Issue.record("expected unstyled, got \(step)"); return }
        #expect(try dispatcher.read(surface) == (try Self.layer()))
    }

    @Test func noStyleSkipsTheDraw() throws {
        let resident = StyleLayerResident<String>(dispatcher: dispatcher)
        var draws = 0
        for style in [nil, LayerStyle.none] {
            let step = try resident.step(content: "a", pixels: { try Self.layer() }, style: style) { _, layer in
                draws += 1
                return layer
            }
            guard case .unstyled = step else { Issue.record("expected unstyled, got \(step)"); return }
        }
        #expect(draws == 0)
    }

    @Test func styledResultIsCutToTheLayerWindow() throws {
        let resident = StyleLayerResident<String>(dispatcher: dispatcher)
        let step = try resident.step(content: "a", pixels: { try Self.layer() }, style: Self.glow, draw: padded)
        guard case .styled(let surface) = step else { Issue.record("expected styled, got \(step)"); return }
        defer { resident.finish(step) }
        #expect(try dispatcher.read(surface) == (try Self.layer()))
    }

    @Test func windowCentresAndClamps() {
        #expect(StyleLayerResident<String>.window(styled: (24, 13), layer: (4, 3)) == .init(x: 10, y: 5, width: 4, height: 3))
        #expect(StyleLayerResident<String>.window(styled: (4, 3), layer: (4, 3)) == .init(x: 0, y: 0, width: 4, height: 3))
        #expect(StyleLayerResident<String>.window(styled: (2, 2), layer: (4, 3)) == .init(x: 0, y: 0, width: 2, height: 2))
    }
}
