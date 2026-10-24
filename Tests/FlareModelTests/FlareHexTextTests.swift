// FlareHexTextTests.swift: Flare's hex rules are the kernel's HexText (#5078). NewDocumentSpec writes the same
// upper case "#RRGGBB" as every other app and reads every form HexText reads, the "#RGB" shorthand included,
// but only opaque colours: a background or a fill typed as hex has no alpha.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Test func newDocumentHexIsTheKernelsFormat() {
    for color in [FlareColor(r: 1, g: 0.5, b: 0), FlareColor(r: 0.001, g: 0.999, b: 0.2), FlareColor(r: .nan, g: 2, b: -1)] {
        #expect(NewDocumentSpec.hex(color) == HexText.format(color))
    }
    #expect(NewDocumentSpec.hex(FlareColor(r: 0, g: 0x0A / 255.0, b: 1, a: 0.5)) == "#000AFF")
}

@Test func newDocumentReadsTheKernelsFormsWhenOpaque() {
    #expect(NewDocumentSpec.color(hex: "#F80") == HexText.parse("#FF8800"))
    #expect(NewDocumentSpec.color(hex: " ff8800 ") == HexText.parse("#FF8800"))
    #expect(NewDocumentSpec.color(hex: "#FF8800FF") == HexText.parse("#FF8800"))
    #expect(NewDocumentSpec.color(hex: "#FF880080") == nil)
    #expect(NewDocumentSpec.color(hex: "#GG0000") == nil && NewDocumentSpec.color(hex: "#FF88001") == nil)
}
