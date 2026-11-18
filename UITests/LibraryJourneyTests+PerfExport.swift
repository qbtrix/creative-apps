// LibraryJourneyTests+PerfExport.swift: P8, export throughput (packet
// docs/blueprints/library/features/export.md, Budgets; slice EX-e), on J7B's
// steps. Live (L): ten landscape 6000 × 4000 `shoot` JPEGs at 2048, three runs.
// Each run is timed on the app's own clock from the export sheet's suite.perf
// marks (`export` when Export runs, `progress` when the running row appears,
// `summary` when the result does), so XCUITest's click and polling stay out
// of it, and gated: progress ≤ 100 ms and the whole run ≤ 15 s after Export
// (budget row QB-L9, QB-LIB-7). The runs start once the launch import's
// progress row is gone, so they time the export, not the import beside it, and
// every run is gated after all three ran, so one slow run never hides the
// others' numbers. The numbers, with the test-side wall time,
// go to .build/ui-screens/perf-testExportThroughput.json. The model half is
// gated on a release build in LibraryDevelopBudgetTests+Export.swift.
import Foundation
import XCTest

extension LibraryExportBatchJourneyTests {
    /// The first ten landscape photos of `shoot` by name (every third is portrait).
    static let landscape = (1...15).filter { $0 % 3 != 0 }.map { String(format: "IMG_%04d", $0) }

    /// P8: three exports of ten 6000 × 4000 JPEGs at 2048, each gated on its progress row and whole time.
    @MainActor func testExportThroughput() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        let out = try LibraryFiles.freshPhotoFolder()
        addTeardownBlock { [folder, catalog, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try LibraryFiles.writeShoot(in: folder)
        let library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryImportOnLaunch", "YES",
            "-LibraryCatalogDir", catalog.path, "-LibraryExportTo", out.path, "-SuitePerfProbe", "YES",
        ])
        sortByName(library)
        XCTAssert(library.element("library.import.progress").waitForNonExistence(timeout: 120), "the import never finished")
        select(Self.landscape, library)

        var numbers: [String: String] = [:]
        var misses: [String] = []
        for run in 1...3 {
            openExport(library)
            let started = ProcessInfo.processInfo.systemUptime
            sheetButton("Export", library).click()
            let summary = library.element("library.export.summary")
            XCTAssert(summary.waitForExistence(timeout: 120), "run \(run): no summary within 120 s")
            let wholeMs = (ProcessInfo.processInfo.systemUptime - started) * 1000
            XCTAssertEqual(Self.text(summary), "Exported 10 photos.", "run \(run): the summary")
            let marks = library.perf()?.marks.filter { $0.series == "library.export" } ?? []
            let at = { (name: String) in marks.last { $0.name == name }?.time }
            guard let export = at("export"), let progress = at("progress"), let done = at("summary") else {
                XCTFail("run \(run): suite.perf lacks an export, progress or summary mark: \(marks.map(\.name))")
                closeSheet(library)
                continue
            }
            let (progressMs, appMs) = ((progress - export) * 1000, (done - export) * 1000)
            numbers["P8 run \(run)"] = String(format: "progress-ms=%.0f app-ms=%.0f wall-ms=%.0f", progressMs, appMs, wholeMs)
                + " (gates: progress 100 ms, whole 15000 ms)"
            if progressMs > 100 { misses.append("run \(run): the running row came \(Int(progressMs)) ms after Export") }
            if appMs > 15000 { misses.append("run \(run): ten photos at 2048 took \(Int(appMs)) ms") }
            closeSheet(library)
        }
        report(numbers)
        XCTAssert(misses.isEmpty, "P8 over budget (progress 100 ms, whole 15000 ms): \(misses.joined(separator: "; "))")
        let written = (try? FileManager.default.contentsOfDirectory(atPath: out.path)) ?? []
        XCTAssertEqual(written.count, 30, "three runs of ten wrote \(written.count) files")
        library.app.terminate()
    }

    /// The sheet's Done or Close button, then the sheet is gone.
    @MainActor private func closeSheet(_ library: Journey) {
        let sheet = library.app.sheets.firstMatch
        guard sheet.exists else { return }
        let button = ["Done", "Close"].lazy.map { self.sheetButton($0, library) }.first { $0.exists }
        XCTAssertNotNil(button, "the export sheet has no Done or Close")
        button?.click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "the export sheet didn't close")
    }

    /// Writes `numbers` to .build/ui-screens/perf-testExportThroughput.json and attaches them.
    @MainActor private func report(_ numbers: [String: String]) {
        for (key, value) in numbers.sorted(by: { $0.key < $1.key }) { print("\(key): \(value)") }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(numbers) else { return }
        // This file is UITests/LibraryJourneyTests+PerfExport.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appending(path: ".build/ui-screens")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? json.write(to: folder.appending(path: "perf-testExportThroughput.json"))
        let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        attachment.name = "perf-testExportThroughput"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
