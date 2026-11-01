// PhotoPaletteSymbolTests.swift: Photo's tool palette shows one SF Symbol per tool, each one a symbol that
// exists, no two the same (Wand and Remove both drew wand.and.stars), and Select draws the suite's Select arrow,
// `cursorarrow`, as Flare's and Design's V tool do. macOS only.
import AppKit
import PhotoModel
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoPaletteSymbolTests {
    @Test func everyToolHasItsOwnSymbol() {
        let symbols = PhotoTool.allCases.map(\.systemImage)
        #expect(Set(symbols).count == symbols.count, "shared symbols: \(symbols)")
        for tool in PhotoTool.allCases {
            #expect(NSImage(systemSymbolName: tool.systemImage, accessibilityDescription: nil) != nil, "\(tool): no symbol \(tool.systemImage)")
        }
    }

    @Test func selectDrawsTheSuitesSelectArrow() {
        #expect(PhotoTool.select.systemImage == "cursorarrow")
    }
}
