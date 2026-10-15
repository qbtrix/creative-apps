// HaloOpacityRuleTests.swift: the opacity rule HF-1 holds the viewer canvas
// to (#1161). A half-opaque layer mixes with what is under it in linear
// light, so `keyed` at frame 6 (Ball, sRGB 0.85 0.33 0.25 at opacity 0.5,
// over HaloViewerFidelityTests' backdrop 0.12 0.14 0.18) shows sRGB
// 160 65 56, not the 124 60 55 an sRGB-space mix gives. Runs on Linux and
// macOS.
import CoreRaster
import HaloModel
import Testing

@Test func halfOpaqueBallOverTheBackdropMixesInLinearLight() throws {
    let ball = HaloLayer(
        id: "ball", name: "Ball", kind: .solid, inFrame: 0, outFrame: 1,
        color: HaloLayerColor(red: 0.85, green: 0.33, blue: 0.25), opacity: 0.5)
    let backdrop = HaloLayer(
        id: "backdrop", name: "Backdrop", kind: .solid, inFrame: 0, outFrame: 1,
        color: HaloLayerColor(red: 0.12, green: 0.14, blue: 0.18))
    let comp = HaloComposition(
        id: "c", name: "C", width: 4, height: 4, framesPerSecond: 24, durationFrames: 1, layers: [ball, backdrop])
    let frame = try #require(comp.renderFrame(at: 0, scale: 1))
    let bytes = Array(try frame.pixels.rgba8(colorSpace: .sRGB).prefix(4))
    let linearMix: [Int] = [160, 65, 56, 255]
    let srgbMix: [Int] = [124, 60, 55, 255]
    #expect(zip(bytes, linearMix).allSatisfy { abs(Int($0) - $1) <= 1 }, "got \(bytes)")
    #expect(abs(Int(bytes[0]) - srgbMix[0]) > 30)
}
