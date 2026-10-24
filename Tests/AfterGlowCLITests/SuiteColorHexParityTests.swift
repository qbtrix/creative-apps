// SuiteColorHexParityTests.swift: SuiteColorValue's "RRGGBB" is the kernel's HexText format without the "#"
// (#5078). SuiteModel links no other module, so it keeps a mirror of HexText's rounding; this test, in a target
// that sees both, pins the mirror to the codec on every byte and on the edges (out of range clamps, a NaN or an
// infinity reads 00), so the two can't drift. The components are written in their own space, never converted.
import SuiteKernel
import SuiteModel
import Testing

@Test func suiteColorHexIsHexTextWithoutTheHash() {
    let edges: [Double] = [-1, 0, 0.001, 0.5, 0.999, 1, 2, .nan, .infinity, -.infinity]
    let parts = edges + (0...255).map { Double($0) / 255 }
    for v in parts {
        for space in [SuiteColorSpace.sRGB, .displayP3] {
            let color = SuiteColorValue(space: space, red: v, green: 1 - v, blue: v / 2, alpha: 0.5)
            #expect(color.hex == String(HexText.format(FillColor(r: v, g: 1 - v, b: v / 2)).dropFirst()), "\(v)")
        }
    }
}
