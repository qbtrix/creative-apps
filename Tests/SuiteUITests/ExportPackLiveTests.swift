// ExportPackLiveTests.swift: export-pack XP-8. The gallery's `export-pack` page on live: its board is a local
// export target that plans each pick through ExportRules on the 1000 × 1250 artwork and runs a fake export
// through FakeMedia, so an Export writes a still at exactly the planned pixels; a pick the rules refuse writes
// nothing and the run fails with the rules' sentence. The page is no longer on placeholders. macOS only (SuiteUI).
import SuiteKernel
import SuiteModel
import Testing

@testable import SuiteUI

@MainActor @Suite struct ExportPackLiveTests {
    /// The page opens on 1080 × 1350 JPEG; Export writes a 1080 × 1350 JPEG and finishes with its name.
    @Test func anExportWritesThePlannedSize() {
        var board = GalleryExportBoard()
        #expect(board.run == .editing(GalleryExportPack.pick))
        let line = board.export()
        #expect(line == "export jpeg: wrote export-pack.jpg at 1080 × 1350 px")
        #expect(board.run == .finished(GalleryExportPack.pick, ["export-pack.jpg"]))
        let still = board.media.stills.last
        #expect(board.media.stills.count == 1 && still?.format == .jpeg)
        #expect(still?.frame.width == 1080 && still?.frame.height == 1350)
    }

    /// The plan is the rules' answer, not the size the pick names: Long edge 2048 writes 1638 × 2048.
    @Test func thePlanComesFromTheRules() throws {
        var board = GalleryExportBoard()
        let edited = board.edit("size longEdge") { $0.size = .longEdge(2048) }
        #expect(edited == "size longEdge")
        let planned = try GalleryExportBoard.plan(board.pick)
        #expect(planned.width == 1638 && planned.height == 2048)
        _ = board.export()
        #expect(board.media.stills.last?.frame.width == 1638 && board.media.stills.last?.frame.height == 2048)
        #expect(GalleryExportBoard.options(GalleryExportPack.pick)
            == SuiteExportOptions(format: "jpeg", size: .pixels(width: 1080, height: 1350), quality: 0.9, metadata: .all))
    }

    /// 1080 × 1351 without stretch is refused with the rules' sentence: nothing written, the run failed.
    @Test func aRefusedPlanWritesNothing() {
        var board = GalleryExportBoard()
        _ = board.edit("size") { $0.size = .pixels(width: 1080, height: 1351) }
        let line = board.export()
        let why = "1080 × 1351 doesn't keep the artwork's 4:5 shape. Unlock the ratio to stretch."
        #expect(line == "export jpeg: refused, \(why)")
        #expect(board.run == .failed(board.pick, why))
        #expect(board.media.stills.isEmpty)
    }

    /// Done after an export opens the sheet again on the same pick; an edit on a finished run does too.
    @Test func closingAfterAnExportEditsAgain() {
        var board = GalleryExportBoard()
        #expect(board.close() == "cancel" && board.run == .editing(GalleryExportPack.pick))
        _ = board.export()
        #expect(board.close() == "done" && board.run == .editing(GalleryExportPack.pick))
        _ = board.export()
        _ = board.edit("metadata noLocation") { $0.metadata = .noLocation }
        #expect(board.run == .editing(ExportPick(format: "jpeg", quality: 0.9, metadata: .noLocation,
                                                 size: .pixels(width: 1080, height: 1350))))
    }

    /// SVG plans at Scale (the sheet offers no other mode) and the page's fake writer, a still writer, says so.
    @Test func aVectorPlansAtScaleAndIsNotWritten() throws {
        var board = GalleryExportBoard()
        _ = board.edit("format svg") { $0.format = "svg" }
        #expect(GalleryExportBoard.options(board.pick).size == .scale(1))
        let planned = try GalleryExportBoard.plan(board.pick)
        #expect(planned.width == 1000 && planned.height == 1250)
        let line = board.export()
        #expect(line.hasPrefix("export svg: refused,") && line.contains("1000 × 1250 px"), "\(line)")
        #expect(board.media.stills.isEmpty)
    }
}
