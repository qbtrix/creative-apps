// ExportPackRowsTests.swift: export-pack XP-4. The Size row's arithmetic
// (ExportSheetRows' size statics over ExportRules): the ratio lock fills the
// other side, unlocking stretches, Long edge reads the pixels it writes, a
// mode switch carries the size it was at, and a vector format offers Scale
// only and no Metadata row. Journey step 2 to 5 of
// docs/blueprints/suiteui/features/export-pack.md. macOS only.
import SuiteKernel
import Testing

@testable import SuiteUI

@MainActor @Suite struct ExportPackRowsTests {
    let source = (width: 1000, height: 1250)

    @Test func typingAWidthWithTheLockOnFillsTheHeight() {
        let typed = ExportSheetRows.typing(width: 1080, in: .pixels(width: 1000, height: 1250), source: source)
        #expect(typed == .pixels(width: 1080, height: 1350))
        #expect(ExportSheetRows.readout(typed, source: source).text == "1080 × 1350 px")
        let tall = ExportSheetRows.typing(height: 2500, in: typed, source: source)
        #expect(tall == .pixels(width: 2000, height: 2500))
    }

    @Test func unlockingAndTyping1351ReadsStretched() {
        let unlocked = ExportSheetRows.locking(false, .pixels(width: 1080, height: 1350), source: source)
        #expect(unlocked == .pixels(width: 1080, height: 1350, stretch: true))
        #expect(ExportSheetRows.readout(unlocked, source: source).text == "1080 × 1350 px")
        let typed = ExportSheetRows.typing(height: 1351, in: unlocked, source: source)
        #expect(typed == .pixels(width: 1080, height: 1351, stretch: true))
        let readout = ExportSheetRows.readout(typed, source: source)
        #expect(readout.text == "1080 × 1351 px, stretched" && !readout.refused)
        let relocked = ExportSheetRows.locking(true, typed, source: source)
        #expect(relocked == .pixels(width: 1080, height: 1350))
    }

    @Test func aLockedShapeThatDoesNotMatchIsRefused() {
        let readout = ExportSheetRows.readout(.pixels(width: 1080, height: 1351), source: source)
        #expect(readout.refused)
        #expect(readout.text == "1080 × 1351 doesn't keep the artwork's 4:5 shape. Unlock the ratio to stretch.")
    }

    @Test func aRefusedSizeBlocksExportAndSaysWhy() {
        let refused = ExportPick(format: "jpeg", size: .pixels(width: 1080, height: 1351))
        let rows = ExportSheetRows(.editing(refused), formats: GalleryExportPack.formats, source: source) { $0 }
        #expect(rows.startBlock == "1080 × 1351 doesn't keep the artwork's 4:5 shape. Unlock the ratio to stretch.")
        var fine = refused
        fine.size = .pixels(width: 1080, height: 1350)
        #expect(ExportSheetRows(.editing(fine), formats: GalleryExportPack.formats, source: source) { $0 }.startBlock == nil)
        let running = ExportSheetRows(.running(fine, done: 0, total: 1), formats: GalleryExportPack.formats, source: source) { $0 }
        #expect(running.startBlock == "The export is already under way or done.")
    }

    @Test func longEdge2048Reads1638By2048() {
        #expect(ExportSheetRows.readout(.longEdge(2048), source: source).text == "1638 × 2048 px")
        #expect(ExportSheetRows.readout(.scale(2), source: source).text == "2000 × 2500 px")
    }

    @Test func switchingModesCarriesTheSize() {
        let pixels = ExportSheetRows.switching(.scale(1), to: .pixels, source: source)
        #expect(pixels == .pixels(width: 1000, height: 1250))
        #expect(ExportSheetRows.switching(.pixels(width: 1080, height: 1350), to: .longEdge, source: source) == .longEdge(1350))
        #expect(ExportSheetRows.switching(.longEdge(2500), to: .scale, source: source) == .scale(2))
        #expect(ExportSheetRows.sizeMode(of: .longEdge(9)) == .longEdge)
        #expect(ExportSheetRows.SizeMode.allCases.map(\.title) == ["Scale", "Pixels", "Long edge"])
    }

    @Test func svgHidesMetadataAndOffersScaleOnly() {
        let formats = GalleryExportPack.formats
        let jpeg = ExportPick(format: "jpeg", metadata: .noLocation, size: .longEdge(2048))
        let still = ExportSheetRows(.editing(jpeg), formats: formats, source: source) { $0 }
        #expect(still.sizeModes == [.scale, .pixels, .longEdge])
        #expect(still.rows.contains(.metadata(.noLocation)))
        var svgPick = jpeg
        svgPick.format = "svg"
        let svg = ExportSheetRows(.editing(svgPick), formats: formats, source: source) { $0 }
        #expect(svg.sizeModes == [.scale])
        #expect(svg.rows == [.format("svg"), .pixels(.scale(1), source: 1000, 1250)])
        var png = jpeg
        png.format = "png"
        #expect(ExportSheetRows(.editing(png), formats: formats, source: source) { $0 }.rows.contains(.metadata(.noLocation)))
    }

    @Test func everySizeControlHangsOffThePrefix() {
        let ids = ExportSheetIDs("suite.export")
        #expect(ids.size == "suite.export.size" && ids.metadata == "suite.export.metadata")
        #expect(ids.sizeMode(.longEdge) == "suite.export.size.mode.longEdge")
        #expect([ids.size(.width), ids.size(.height), ids.size(.lock), ids.size(.longEdge), ids.size(.scale), ids.size(.readout)] == [
            "suite.export.size.width", "suite.export.size.height", "suite.export.size.lock", "suite.export.size.longEdge",
            "suite.export.size.scale", "suite.export.size.readout",
        ])
    }
}
