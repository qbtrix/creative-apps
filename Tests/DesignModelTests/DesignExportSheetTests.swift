// DesignExportSheetTests.swift: what Design's export sheet reads (design-export DE-6),
// on DesignFixtures.cards (Desktop node-1 holding A node-2 and Hidden node-10). Linux and macOS.
import DesignModel
import Testing

@Suite struct DesignExportSheetTests {
    @Test func scopesReadAsTheirChips() {
        #expect(DesignExportScope.allCases.map(\.title) == ["Selection", "Frame", "Page"])
    }

    @Test func theSheetOpensOnFrameWhenSelectionHasNothing() {
        var cards = DesignFixtures.cards
        cards.rememberExport(DesignExportOptions(format: .svg, scale: 2, scope: .selection))
        #expect(cards.exportSheetDefaults == DesignExportOptions(format: .svg, scale: 2, scope: .frame))
        cards.selectItem("node-2")
        #expect(cards.exportSheetDefaults == DesignExportOptions(format: .svg, scale: 2, scope: .selection))
        cards.rememberExport(DesignExportOptions(format: .pdf, scale: 1, scope: .page))
        cards.selectItem("node-1")
        #expect(cards.exportSheetDefaults.scope == .page)
    }

    @Test func scaleIsWholeOneToThree() {
        let options = DesignExportOptions(format: .png, scale: 2, scope: .page)
        #expect(options.scaled(1).scale == 1)
        #expect(options.scaled(2.6).scale == 3)
        #expect(options.scaled(0.25).scale == 1)
        #expect(options.scaled(4).scale == 3)
        #expect(options.scaled(.nan).scale == 2)
        #expect(options.scaled(.infinity).scale == 2)
        #expect(options.scaled(3).format == .png && options.scaled(3).scope == .page)
    }

    @Test func scaleIsOffForVectorFormats() {
        #expect(DesignExportOptions(format: .png, scale: 2, scope: .page).scaleHelp == nil)
        #expect(DesignExportOptions(format: .svg, scale: 2, scope: .page).scaleHelp == "SVG and PDF are vectors, so they don't take a scale.")
        #expect(DesignExportOptions(format: .pdf, scale: 1, scope: .frame).scaleHelp == "SVG and PDF are vectors, so they don't take a scale.")
    }

    @Test func theRunShowsItsOptionsUntilIdle() {
        let options = DesignExportOptions(format: .pdf, scale: 1, scope: .page)
        #expect(DesignExportRun.idle.shownOptions == nil)
        #expect(DesignExportRun.editing(options).shownOptions == options)
        #expect(DesignExportRun.running(options, done: 1, total: 2).shownOptions == options)
        #expect(DesignExportRun.finished(options, ["Page 1.pdf"]).shownOptions == options)
        #expect(DesignExportRun.failed(options, "No.").shownOptions == options)
    }

    @Test func theListIsThePlan() {
        var cards = DesignFixtures.cards
        cards.selectItem("node-1")
        let one = cards.exportRows(DesignExportOptions(format: .png, scale: 1, scope: .frame))
        #expect(one == [DesignExportRow(id: "node-1", text: "Desktop.png 1440 × 1024 pt, 1x, 1440 × 1024 px", skipped: nil)])
        let two = cards.exportRows(DesignExportOptions(format: .png, scale: 2, scope: .frame))
        #expect(two.map(\.text) == ["Desktop.png 1440 × 1024 pt, 2x, 2880 × 2048 px"])
        let svg = cards.exportRows(DesignExportOptions(format: .svg, scale: 3, scope: .frame))
        #expect(svg.map(\.text) == ["Desktop.svg 1440 × 1024 pt"])
        let page = cards.exportRows(DesignExportOptions(format: .pdf, scale: 1, scope: .page))
        #expect(page.map(\.text) == ["Page 1.pdf 1440 × 1024 pt"])
    }

    @Test func aHiddenSelectedLayerIsListedSkipped() {
        var cards = DesignFixtures.cards
        // A click selects even a hidden layer (its row); shift-click can't add one.
        cards.selectItem("node-10")
        cards.toggleSelection("node-2")
        #expect(cards.selectedNodeIDs.count == 2)
        let rows = cards.exportRows(DesignExportOptions(format: .png, scale: 1, scope: .selection))
        #expect(rows.map(\.id) == ["node-2", "node-10"])
        #expect(rows.first?.skipped == nil)
        #expect(rows.last == DesignExportRow(id: "node-10", text: "Hidden", skipped: "Hidden layers aren't exported"))
        // Frame scope names no hidden layer.
        #expect(cards.exportRows(DesignExportOptions(format: .png, scale: 1, scope: .frame)).allSatisfy { $0.skipped == nil })
    }

    @Test func aRefusedPlanListsNothing() {
        let cards = DesignFixtures.cards
        #expect(cards.exportRows(DesignExportOptions(format: .png, scale: 1, scope: .selection)).isEmpty)
        #expect(DesignWorkspace().exportRows(DesignExportOptions()).isEmpty)
    }

    // DE-7: the fake run.
    @Test func theFakeRunWritesThePlansNamesOrSaysWhyNot() {
        var cards = DesignFixtures.cards
        cards.selectItem("node-1")
        #expect(cards.exportFiles(DesignExportOptions(format: .svg, scale: 1, scope: .frame)) == .success(["Desktop.svg"]))
        #expect(cards.exportFiles(DesignExportOptions(format: .pdf, scale: 1, scope: .page)) == .success(["Page 1.pdf"]))
        let refused = DesignWorkspace().exportFiles(DesignExportOptions())
        #expect(refused == .failure(DesignExportFailure(DesignRefusal.nothingToExport.help)))
    }

    @Test func aFakeStepFailsOnlyTheNamedFile() throws {
        try DesignWorkspace.fakeWrite("Desktop.png", failing: nil)
        try DesignWorkspace.fakeWrite("Desktop.png", failing: "A.png")
        #expect(throws: DesignExportFailure("Desktop.png couldn't be written.")) {
            try DesignWorkspace.fakeWrite("Desktop.png", failing: "Desktop.png")
        }
        #expect(String(describing: DesignExportFailure.unwritten("A.png")) == "A.png couldn't be written.")
    }

    @Test func theSummaryCountsTheFiles() {
        #expect(DesignWorkspace.exportSummary(["Desktop.png"]) == "Exported 1 file: Desktop.png.")
        #expect(DesignWorkspace.exportSummary(["A.png", "B.png", "C.png"]) == "Exported 3 files.")
        #expect(DesignWorkspace.exportSummary([]) == "Exported nothing.")
    }

    @Test func aFinishedRunShowsTheSummary() {
        let options = DesignExportOptions()
        #expect(DesignExportRun.finished(options, ["A.png", "B.png"]).summarized == .finished(options, ["2 files."]))
        #expect(DesignExportRun.finished(options, ["A.png"]).summarized == .finished(options, ["1 file: A.png."]))
        #expect(DesignExportRun.running(options, done: 1, total: 2).summarized == .running(options, done: 1, total: 2))
        #expect(DesignExportRun.failed(options, "No.").summarized == .failed(options, "No."))
    }
}
