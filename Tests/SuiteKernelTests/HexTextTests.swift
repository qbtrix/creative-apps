// HexTextTests.swift: the suite's one hex colour codec (#5078), String <-> FillColor in sRGB 0...1 with
// straight alpha. Parse takes "#RGB", "#RRGGBB" and "#RRGGBBAA", with or without one "#", either case,
// surrounding spaces ignored; anything else is nil. Format writes upper case "#RRGGBB", and "#RRGGBBAA" only
// when asked for alpha and the alpha isn't FF. Channels round to the nearest byte, clamp, and a NaN or an
// infinity reads 00. The SuiteKernel.HexText mutation plan plants its bugs against these tests.
import Testing
import SuiteKernel

@Suite struct HexTextTests {
    static func bytes(_ color: FillColor?) -> [UInt8]? { color.map { [$0.r, $0.g, $0.b, $0.a].map(HexText.byte) } }

    @Test func shortAndLongFormsRead() {
        #expect(Self.bytes(HexText.parse("#F80")) == [0xFF, 0x88, 0x00, 0xFF])
        #expect(Self.bytes(HexText.parse(" #ff8800 ")) == [0xFF, 0x88, 0x00, 0xFF])
        #expect(Self.bytes(HexText.parse("FF8800")) == [0xFF, 0x88, 0x00, 0xFF])
        #expect(Self.bytes(HexText.parse("#1877f2")) == [0x18, 0x77, 0xF2, 0xFF])
        #expect(Self.bytes(HexText.parse("#FF880080")) == [0xFF, 0x88, 0x00, 0x80])
        #expect(Self.bytes(HexText.parse("ff880000")) == [0xFF, 0x88, 0x00, 0x00])
        #expect(HexText.parse("#000000") == FillColor(r: 0, g: 0, b: 0, a: 1))
    }

    @Test func whatIsNotAHexColourIsNil() {
        let invalid = ["", "#", "##FF8800", "#GG0000", "#FF88001", "#12345", "F8", "#F8", "+12345", "-12345",
                       "#+1234", "#FF 880", "#FF8800FF00", "0x1234"]
        for text in invalid { #expect(HexText.parse(text) == nil, "\(text) read as a colour") }
    }

    @Test func formatWritesUpperCaseSixDigits() {
        #expect(HexText.format(FillColor(r: 1, g: 0.5, b: 0)) == "#FF8000")
        #expect(HexText.format(FillColor(r: 0, g: 0x0A / 255.0, b: 1)) == "#000AFF")
        #expect(HexText.format(FillColor(r: 1, g: 0, b: 0, a: 0.5)) == "#FF0000")
    }

    @Test func alphaIsWrittenOnlyWhenAskedAndNotOpaque() {
        #expect(HexText.format(FillColor(r: 1, g: 0, b: 0, a: 0.5), alpha: true) == "#FF000080")
        #expect(HexText.format(FillColor(r: 1, g: 0, b: 0, a: 0), alpha: true) == "#FF000000")
        #expect(HexText.format(FillColor(r: 1, g: 0, b: 0, a: 1), alpha: true) == "#FF0000")
        #expect(HexText.format(FillColor(r: 1, g: 0, b: 0, a: 0.999), alpha: true) == "#FF0000")
    }

    @Test func channelsRoundClampAndReadNonFiniteAsZero() {
        #expect(HexText.byte(0.5) == 128)
        #expect(HexText.byte(0.001) == 0 && HexText.byte(0.999) == 255)
        #expect(HexText.byte(-1) == 0 && HexText.byte(2) == 255)
        #expect(HexText.byte(.nan) == 0 && HexText.byte(.infinity) == 0 && HexText.byte(-.infinity) == 0)
        #expect(HexText.format(FillColor(r: .nan, g: 2, b: -1)) == "#00FF00")
    }

    @Test func everyByteRoundTrips() {
        for byte in UInt8.min...UInt8.max {
            let digits = (byte < 16 ? "0" : "") + String(byte, radix: 16, uppercase: true)
            let text = "#" + digits + digits + digits + digits
            #expect(Self.bytes(HexText.parse(text)) == [byte, byte, byte, byte])
            #expect(HexText.parse(text).map { HexText.format($0, alpha: true) } == (byte == 255 ? "#FFFFFF" : text))
        }
        for text in ["#1877F2", "#000AFF", "#1877F240"] {
            #expect(HexText.parse(text).map { HexText.format($0, alpha: true) } == text)
        }
    }
}
