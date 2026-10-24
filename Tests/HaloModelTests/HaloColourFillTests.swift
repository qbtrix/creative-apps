// HaloColourFillTests.swift: Halo's layer colour converts to and from the kernel's FillColor (both sRGB 0...1)
// (#5078). It stays its own type because it is stored in Halo documents without alpha; `fill` is opaque, the
// init drops alpha, and `bytes`, the colour row's 8-bit form, is HexText's rounding.
@testable import HaloModel
import SuiteKernel
import Testing

@Test func haloLayerColorConvertsThroughTheKernel() {
    let color = HaloLayerColor(red: 0.1, green: 0.5, blue: 0.9)
    #expect(HaloLayerColor(color.fill) == color)
    #expect(color.fill == FillColor(r: 0.1, g: 0.5, b: 0.9, a: 1))
    #expect(HaloLayerColor(FillColor(r: 0.2, g: 0.4, b: 0.6, a: 0.5)) == HaloLayerColor(red: 0.2, green: 0.4, blue: 0.6))
}

@Test func haloBytesRoundLikeHexText() {
    for v in [0.0, 0.001, 0.5, 0.999, 1, -1, 2, .nan, .infinity] {
        let b = HaloLayerColor(red: v, green: v, blue: v).bytes
        #expect([b.red, b.green, b.blue] == Array(repeating: HexText.byte(v), count: 3), "\(v)")
    }
    #expect(HaloLayerColor(red: 0.5, green: 0, blue: 1).bytes == (128, 0, 255))
}
