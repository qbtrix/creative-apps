// DesignHexTextTests.swift: Design's colour bridges are the kernel's (#5078). SVG export writes HexText's digits in
// lower case, and DesignColor converts to and from the kernel's FillColor (both sRGB) with HexText's rounding:
// every byte round trips, out-of-range parts clamp, a NaN reads 0 and alpha is dropped.
@testable import DesignModel
import SuiteKernel
import Testing

@Test func svgHexIsTheKernelsFormatLowerCased() {
    #expect(DesignSVG.hex(DesignColor(0x18, 0x77, 0xF2)) == "#1877f2")
    #expect(DesignSVG.hex(DesignColor(0, 0x0A, 0xFF)) == "#000aff")
    for byte in UInt8.min...UInt8.max {
        let color = DesignColor(byte, 255 - byte, byte / 3)
        #expect(DesignSVG.hex(color) == HexText.format(color.kernelColor).lowercased())
        #expect(DesignColor(kernel: color.kernelColor) == color)
    }
}

@Test func designColorReadsTheKernelsColourWithItsRounding() {
    #expect(DesignColor(kernel: FillColor(r: 0.5, g: 0.001, b: 0.999, a: 0.2)) == DesignColor(128, 0, 255))
    #expect(DesignColor(kernel: FillColor(r: .infinity, g: -1, b: .nan)) == DesignColor(0, 0, 0))
    #expect(DesignColor(1, 2, 3).kernelColor.a == 1)
}
