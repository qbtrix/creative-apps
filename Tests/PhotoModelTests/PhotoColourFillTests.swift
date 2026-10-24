// PhotoColourFillTests.swift: Photo's SampledColor converts to and from the kernel's FillColor (both sRGB) with
// HexText's rounding (#5078): every byte round trips, out-of-range channels clamp, a NaN reads 0, alpha is dropped.
// It stays its own type because it is ColorSampling's output contract; the bridge keeps it from drifting.
@testable import PhotoModel
import SuiteKernel
import Testing

@Test func sampledColorConvertsThroughTheKernel() {
    for byte in UInt8.min...UInt8.max {
        let color = SampledColor(red: byte, green: 255 - byte, blue: byte / 5)
        #expect(SampledColor(color.fill) == color)
        #expect(HexText.format(color.fill) == HexText.format(FillColor(r: Double(byte) / 255, g: Double(255 - byte) / 255, b: Double(byte / 5) / 255)))
    }
    #expect(SampledColor(FillColor(r: 0.5, g: 2, b: .nan, a: 0.1)) == SampledColor(red: 128, green: 255, blue: 0))
    #expect(SampledColor(red: 1, green: 2, blue: 3).fill.a == 1)
}
