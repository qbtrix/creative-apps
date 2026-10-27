// ExportPackPageTests.swift: export-pack XP-3. The gallery index lists
// `export-pack` (SJ0), ExportPick's size is nil unless a host passes one so
// existing callers read as before, and the sheet's rows place the Size and
// Metadata placeholders: a set size replaces the Scale row, a metadata policy
// adds its row after Quality, and `showsSize: false` still drops the size.
// macOS only.
import SuiteKernel
import Testing

@testable import SuiteUI

@MainActor @Suite struct ExportPackPageTests {
    let formats = GalleryExportPack.formats

    @Test func theIndexListsTheExportPackPage() {
        #expect(SuiteGallery.pageNames.contains("export-pack"))
        #expect(SuiteGallery.resolve("export-pack") == .page("export-pack"))
    }

    @Test func sizeDefaultsToNilSoExistingPicksReadAsBefore() {
        #expect(ExportPick(format: "png").size == nil)
        #expect(ExportPick(format: "jpeg", scale: 2, quality: 0.8, metadata: .all).size == nil)
        let sized = ExportPick(format: "jpeg", size: .longEdge(2048))
        #expect(sized.size == .longEdge(2048) && sized != ExportPick(format: "jpeg"))
    }

    @Test func aSetSizeAndPolicyShowTheirPlaceholderRows() {
        let pick = ExportPick(format: "jpeg", quality: 0.9, metadata: .noLocation, size: .pixels(width: 1080, height: 1350))
        let rows = ExportSheetRows(.editing(pick), formats: formats, source: (1000, 1250)) { $0 }
        #expect(rows.rows == [
            .format("jpeg"), .pixels(.pixels(width: 1080, height: 1350), source: 1000, 1250), .quality(0.9), .metadata(.noLocation),
        ])
        let plain = ExportSheetRows(.editing(ExportPick(format: "png", scale: 2)), formats: formats) { $0 }
        #expect(plain.rows == [.format("png"), .size(2)])
        let hostScale = ExportSheetRows(.editing(pick), formats: formats, showsSize: false) { $0 }
        #expect(hostScale.rows == [.format("jpeg"), .quality(0.9), .metadata(.noLocation)])
    }

    @Test func theSizePlaceholderReadsTheSize() {
        #expect(ExportSheetRows.sizeText(.pixels(width: 1080, height: 1350), source: 1000, 1250) == "1080 × 1350 px")
        #expect(ExportSheetRows.sizeText(.pixels(width: 1080, height: 1351, stretch: true), source: 1000, 1250)
            == "1080 × 1351 px, stretched")
        #expect(ExportSheetRows.sizeText(.longEdge(2048), source: 1000, 1250) == "Long edge 2048 px")
        #expect(ExportSheetRows.sizeText(.scale(2), source: 1000, 1250) == "2x of 1000 × 1250 px")
    }
}
