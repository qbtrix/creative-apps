// HexColorBridgeTests.swift: adopt-suiteui-chrome AC-colour (finding #4086). Each app's bridge onto SuiteUI's
// HexColor keeps every 8-bit channel in its own place, both ways: Design's DesignColor, Halo's HaloLayerColor,
// Photo's ToolOptions and ToolOptionEdit.brushColor, and Flare's FlareColor. The channels are asymmetric
// (0x18, 0x77, 0xF2), so a swap of any two fails, and each direction has its own test, so two swaps that undo
// each other in a round trip still fail. One suite per app, so `scripts/test-scope` runs it with that app.
// macOS only.
import DesignModel
import FlareModel
import HaloModel
import PhotoModel
import SuiteUI
import Testing

@testable import DesignApp
@testable import FlareApp
@testable import HaloApp
@testable import PhotoApp

/// The test color: every channel different, so a swap of any two shows.
private let picked = HexColor(0x18, 0x77, 0xF2)

@Suite struct DesignHexColorBridgeTests {
    @Test func aHexColorBecomesTheSameDesignColor() {
        #expect(DesignColor(hex: picked) == DesignColor(0x18, 0x77, 0xF2))
    }

    @Test func aDesignColorReadsAsTheSameHexColor() {
        #expect(DesignColor(0x18, 0x77, 0xF2).hex == picked)
    }

    @Test func aHexColorRoundTripsThroughDesign() {
        #expect(DesignColor(hex: picked).hex == picked)
    }
}

@Suite struct HaloHexColorBridgeTests {
    @Test func aHexColorBecomesTheSameLayerColor() {
        let color = HaloLayerColor(hex: picked)
        #expect(color == HaloLayerColor(bytes: 0x18, 0x77, 0xF2))
        #expect(color.bytes.red == 0x18 && color.bytes.green == 0x77 && color.bytes.blue == 0xF2)
    }

    @Test func aLayerColorReadsAsTheSameHexColor() {
        #expect(HaloLayerColor(red: 0x18 / 255.0, green: 0x77 / 255.0, blue: 0xF2 / 255.0).hex == picked)
    }

    @Test func aHexColorRoundTripsThroughHalo() {
        #expect(HaloLayerColor(hex: picked).hex == picked)
    }
}

@Suite struct PhotoHexColorBridgeTests {
    @Test func aHexColorBecomesTheSameBrushColorEdit() {
        #expect(ToolOptionEdit.brushColor(picked) == .color(red: 0x18, green: 0x77, blue: 0xF2))
    }

    @Test func theBrushColorReadsAsTheSameHexColor() {
        var options = ToolOptions()
        options.apply(.color(red: 0x18, green: 0x77, blue: 0xF2))
        #expect(options.hex == picked)
    }

    @Test func aHexColorRoundTripsThroughTheBrush() {
        var options = ToolOptions()
        options.apply(.brushColor(picked))
        #expect(options.hex == picked)
    }
}

@Suite struct FlareHexColorBridgeTests {
    @Test func aHexColorBecomesTheSameOpaqueFlareColor() {
        let color = FlareColor(hex: picked)
        #expect(color == FlareColor(r: 0x18 / 255.0, g: 0x77 / 255.0, b: 0xF2 / 255.0))
        #expect(color?.a == 1)
    }

    @Test func everyHexColorIsAFlareColor() {
        // HexColor.text is always "#RRGGBB", so the bridge never refuses one: black and white included.
        #expect(FlareColor(hex: .black) == FlareColor(r: 0, g: 0, b: 0))
        #expect(FlareColor(hex: HexColor(255, 255, 255)) == FlareColor(r: 1, g: 1, b: 1))
    }

    @Test func aFlareColorReadsAsTheSameHexColor() {
        #expect(FlareColor(r: 0x18 / 255.0, g: 0x77 / 255.0, b: 0xF2 / 255.0).hex == picked)
    }

    @Test func aHexColorRoundTripsThroughFlare() {
        #expect(FlareColor(hex: picked)?.hex == picked)
    }

    @Test func anOutOfRangeFlareColorClampsInsteadOfFallingBackToWhite() {
        // NewDocumentSpec.hex clamps each channel (a NaN or infinity reads 0), so the white fallback is
        // never reached: a color the engine holds outside 0...1 still reads as its clamped channels.
        #expect(FlareColor(r: .nan, g: 2, b: -1).hex == HexColor(0, 255, 0))
        #expect(FlareColor(r: .infinity, g: 0x77 / 255.0, b: 0.5).hex == HexColor(0, 0x77, 0x80))
    }
}
