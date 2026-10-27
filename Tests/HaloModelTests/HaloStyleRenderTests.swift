// HaloStyleRenderTests.swift: layer-styles HY-6, the frame renderer's checks, written first. Each frame's draw
// item carries the layer's style with its keyable numbers sampled at that frame: Glow Size keyed 0 to 20 over 30
// frames is 0, 10 and 20 at frames 0, 15 and 30, and an unkeyed shadow is the same on every frame. The pixels are
// SuiteImaging's StyleProgram: until LS-8 gives `render` its body the reach checks wait, and a styled layer draws
// unstyled. Linux and macOS.
import CoreRaster
@testable import HaloModel
import SuiteImaging
import Testing

@Suite struct HaloStyleRenderTests {
    /// A white outer glow `size` px at full opacity.
    static func glow(_ size: Double) -> LayerStyle {
        LayerStyle(effects: [
            StyleEffect(kind: .outerGlow, isEnabled: true, blendMode: .normal, opacity: 1,
                        parameters: .glow(StyleGlow(color: .white, spread: 0, size: size))),
        ], fillOpacity: 1)
    }

    /// A black drop shadow 6 px away, 4 px soft, at 50%.
    static let shadow = LayerStyle(effects: [
        StyleEffect(kind: .dropShadow, isEnabled: true, blendMode: .multiply, opacity: 0.5,
                    parameters: .shadow(StyleShadow(color: .black, angle: 120, distance: 6, spread: 0, size: 4))),
    ], fillOpacity: 1)

    /// A 200 × 120 composition holding one red 40 × 40 square at (80, 40), styled with `style`.
    static func comp(_ style: LayerStyle?, tracks: [String: [HaloKeyframe]] = [:]) -> HaloComposition {
        var layer = HaloLayer(
            id: "s", name: "Square", kind: .solid, inFrame: 0, outFrame: 48,
            color: HaloLayerColor(red: 1, green: 0, blue: 0), rect: HaloLayerRect(x: 80, y: 40, width: 40, height: 40))
        layer.style = style
        layer.tracks = tracks
        return HaloComposition(
            id: "comp-1", name: "Comp", width: 200, height: 120, framesPerSecond: 24, durationFrames: 48, layers: [layer])
    }

    static let keyedGlow = comp(glow(10), tracks: ["glowSize": [HaloKeyframe(frame: 0, value: 0), HaloKeyframe(frame: 30, value: 20)]])

    static func style(_ c: HaloComposition, at frame: Int) -> LayerStyle? {
        LiveFrameDrawing().drawList(c, at: frame).items.first?.style
    }

    static func glowSize(_ style: LayerStyle?) -> Double? {
        guard case .glow(let g)? = style?.effect(.outerGlow)?.parameters else { return nil }
        return g.size
    }

    static func render(_ c: HaloComposition, at frame: Int) throws -> PixelBuffer {
        try #require(
            c.renderFrame(at: frame, scale: 1, drawing: LiveFrameDrawing(), rendering: LiveFrameRendering(), text: nil)
        ).pixels
    }

    /// The least alpha that counts as lit: one 8-bit level.
    static let lit: Float = 1.0 / 255

    /// How far left of the square's left edge (x = 80) the glow lights row 60.
    static func reach(_ pixels: PixelBuffer) throws -> Int {
        var x = 79
        while x >= 0, try pixels.pixel(x: x, y: 60).a >= Self.lit { x -= 1 }
        return 79 - x
    }

    @Test func keyedStyleFollowsFrame() {
        #expect(Self.glowSize(Self.style(Self.keyedGlow, at: 0)) == 0)
        #expect(Self.glowSize(Self.style(Self.keyedGlow, at: 15)) == 10)
        #expect(Self.glowSize(Self.style(Self.keyedGlow, at: 30)) == 20)
    }

    @Test func anUnkeyedShadowIsTheSameOnEveryFrame() {
        let c = Self.comp(Self.shadow)
        for frame in [0, 15, 30, 47] { #expect(Self.style(c, at: frame) == Self.shadow, "frame \(frame)") }
    }

    @Test func anUnstyledLayerCarriesNoStyle() {
        #expect(Self.style(Self.comp(nil), at: 0) == nil)
    }

    @Test func aStyledLayerStillDrawsItsFill() throws {
        let pixels = try Self.render(Self.keyedGlow, at: 30)
        let p = try pixels.pixel(x: 100, y: 60)
        #expect(p.r > 0.9 && p.a > 0.9, "the square's fill is gone: \(p)")
    }

    @Test(.disabled("StyleProgram.render is LS-8's stub")) func glowReachesItsKeyedSize() throws {
        #expect(try Self.reach(Self.render(Self.keyedGlow, at: 0)) == 0, "frame 0 lights pixels outside the box")
        for frame in [15, 30] {
            let reach = try Self.reach(Self.render(Self.keyedGlow, at: frame))
            let bound = StyleRules.reach(try #require(Self.style(Self.keyedGlow, at: frame)))
            #expect(reach > 0 && reach <= bound, "frame \(frame) reaches \(reach) px, StyleRules allows \(bound)")
        }
    }

    @Test(.disabled("StyleProgram.render is LS-8's stub")) func glowIsNotClipped() throws {
        let pixels = try Self.render(Self.keyedGlow, at: 30)
        var right = 120
        while right < 200, try pixels.pixel(x: right, y: 60).a >= Self.lit { right += 1 }
        #expect(try abs((right - 120) - Self.reach(pixels)) <= 1, "the glow sits off centre: placed without its origin")
    }
}
