// HexColorKernelTests.swift: SuiteUI's colour values over SuiteKernel's HexText, the suite's one hex codec
// (#5078). HexColor and the kernel's FillColor convert both ways (both sRGB; HexColor drops alpha), every byte
// round trips, and HexColor's text is HexText's. The SwiftUI bridge goes through Color.Resolved (sRGB) and the
// sampler's NSColor through `usingColorSpace(.sRGB)`, both rounding like HexText (clamp, NaN reads 0). The hex
// field refuses a translucent "#RRGGBBAA" (the row has no alpha), and the fake reads exactly what the field
// reads except the "#RGB" shorthand. macOS only.
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@Test func hexColorAndFillColorConvertBothWaysForEveryByte() {
    for byte in UInt8.min...UInt8.max {
        let color = HexColor(byte, 255 - byte, byte / 2)
        #expect(HexColor(color.fill) == color)
        #expect(color.fill.a == 1)
        #expect(color.text == HexText.format(color.fill))
        #expect(HexColor(color.text) == color)
    }
    #expect(HexColor(FillColor(r: 1, g: 0.5, b: 0, a: 0.25)) == HexColor(255, 128, 0))
    #expect(HexColor(FillColor(r: .nan, g: 2, b: -1)) == HexColor(0, 255, 0))
}

@Test func swiftUIColorBridgeRoundsLikeTheKernel() {
    let color = HexColor(0x18, 0x77, 0xF2)
    #expect(HexColor(color.resolved) == color)
    #expect(HexColor(Color.Resolved(red: 0.5, green: .nan, blue: 1.5)) == HexColor(128, 0, 255))
    #expect(HexColor(color.color.resolve(in: EnvironmentValues())) == color)
}

@Test func nsColorReadsInSRGB() {
    let color = HexColor(0x18, 0x77, 0xF2)
    let ns = NSColor(srgbRed: CGFloat(color.fill.r), green: CGFloat(color.fill.g), blue: CGFloat(color.fill.b), alpha: 1)
    #expect(EyedropperButton.hex(ns) == color)
    #expect(EyedropperButton.hex(NSColor(srgbRed: 0.5, green: 0, blue: 1, alpha: 0.5)) == HexColor(128, 0, 255))
    #expect(EyedropperButton.hex(NSColor(displayP3Red: 0.2, green: 0.2, blue: 0.2, alpha: 1)) == HexColor(51, 51, 51))
}

@Test func hexFieldRefusesATranslucentAlphaForm() {
    #expect(HexColorText().parse("#FF880080") == nil)
    #expect(HexColorText().parse("#ff8800ff") == RGB8(0xFF, 0x88, 0x00))
    #expect(HexColor("#FF880080") == nil)
}

@Test func theFakeReadsWhatTheFieldReadsExceptShorthand() {
    let fake = FakeHexColorEditing(), field = HexColorText()
    for text in ["#1877F2", "1877f2", "#GG0000", "#1234567", "+12345", "#0a0B0c"] {
        #expect(fake.parse(text) == field.parse(text), "\(text)")
    }
    #expect(fake.parse("#F80") == nil && field.parse("#F80") == RGB8(0xFF, 0x88, 0x00))
    #expect(fake.format(RGB8(1, 2, 0xAB)) == field.format(RGB8(1, 2, 0xAB)))
}
