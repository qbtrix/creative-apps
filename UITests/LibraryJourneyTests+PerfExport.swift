// LibraryJourneyTests+PerfExport.swift: P8, export throughput (packet
// docs/blueprints/library/features/export.md, Budgets; slice EX-e), on J7B's
// steps. Live (L): ten landscape 6000 × 4000 `shoot` JPEGs at 2048, three runs;
// each run's time and `progress` mark (S-L8, #782) go to
// .build/ui-screens/perf-testExportThroughput.json. Report-only: it asserts
// the files, never the gates. Skips "waits on EX-13" (then "waits on #782").
import Foundation
import XCTest

extension LibraryExportBatchJourneyTests {
    /// The first ten landscape photos of `shoot` by name (every third is portrait).
    static let landscape = (1...15).filter { $0 % 3 != 0 }.map { String(format: "IMG_%04d", $0) }

    /// P8: three exports of ten 6000 × 4000 JPEGs at 2048; report each run's mark and time.
    @MainActor func testExportThroughput() throws {
        throw XCTSkip("waits on #782")
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
        select(Self.landscape, library)

        var numbers: [String: String] = [:]
        for run in 1...3 {
            openExport(library)
            let started = ProcessInfo.processInfo.systemUptime
            sheetButton("Export", library).click()
            let summary = library.element("library.export.summary")
            XCTAssert(summary.waitForExistence(timeout: 120), "run \(run): no summary within 120 s")
            let wholeMs = (ProcessInfo.processInfo.systemUptime - started) * 1000
            XCTAssertEqual(Self.text(summary), "Exported 10 photos.", "run \(run): the summary")
            let marks = library.perf()?.marks.filter { $0.name.contains("progress") } ?? []
            let mark = marks.last.map { String(format: "progress-ms=%.0f", ($0.time - started) * 1000) }
                ?? "no progress mark in suite.perf (S-L8, #782)"
            numbers["P8 run \(run)"] = String(format: "whole-ms=%.0f ", wholeMs) + mark
                + " report-only (gates: progress 100 ms, whole 15000 ms)"
            closeSheet(library)
        }
        let written = (try? FileManager.default.contentsOfDirectory(atPath: out.path)) ?? []
        XCTAssertEqual(written.count, 30, "three runs of ten wrote \(written.count) files")
        library.app.terminate()
        report(numbers)
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
