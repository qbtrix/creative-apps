// ExportSheetTests.swift: ExportSheetRows follows the kernel's ExportRun, and
// the gallery's fake run climbs to 10 of 10 and finishes (EK-30). macOS only.
import SuiteKernel
import Testing

@testable import SuiteUI

@Suite struct ExportSheetTests {
    func rows(_ run: ExportRun<ExportPick>) -> ExportSheetRows {
        ExportSheetRows(run, formats: GalleryEditorKernelChrome.formats) { $0 }
    }

    @Test func rowsFollowTheRun() {
        let png = ExportPick(format: "png", scale: 2, quality: 0.8)
        let jpeg = ExportPick(format: "jpeg", scale: 1, quality: 0.6)
        let idle = rows(.idle)
        #expect(idle.rows.isEmpty && !idle.editable && idle.progress == nil && idle.line == nil)
        let editing = rows(.editing(jpeg))
        #expect(editing.rows == [.format("jpeg"), .size(1), .quality(0.6)] && editing.editable)
        #expect(rows(.editing(png)).rows == [.format("png"), .size(2)])
        let running = rows(.running(jpeg, done: 4, total: 10))
        #expect(running.rows == editing.rows && !running.editable && running.progress?.text == "Exporting 4 of 10")
        #expect(rows(.running(png, done: 12, total: 10)).progress == ExportProgress(done: 10, total: 10))
        #expect(rows(.running(png, done: -3, total: 0)).progress == ExportProgress(done: 0, total: 1))
        let finished = rows(.finished(png, ["a.png", "b.png"]))
        #expect(!finished.editable && finished.line == .finished("Exported a.png, b.png"))
        #expect(rows(.failed(png, "The disk is full.")).line == .failed("The disk is full."))
        let steps = GalleryEditorKernelChrome.fakeSteps(png)
        #expect(steps.count == 12 && rows(steps[10]).progress == ExportProgress(done: 10, total: 10))
        #expect(rows(steps[11]).line == .finished("Exported editor-kernel.png"))
    }
}
