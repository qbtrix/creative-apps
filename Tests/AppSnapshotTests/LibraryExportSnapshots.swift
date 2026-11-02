// LibraryExportSnapshots.swift: the export sheet (export EX-6) editing, running,
// failed, done, cancelled and a run that failed as a whole, in Light and Dark:
// library-export, library-exporting, library-export-failed, library-export-done,
// library-export-cancelled and library-export-error. macOS only.
import LibraryModel
import SuiteKernel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryExportSnapshots {
    @Test func exportStates() throws {
        let failures = [FileFailure(path: "/Out/IMG_0001.jpg", reason: "The folder is read-only.")]
        let options = ExportOptions(folder: "/Users/me/Pictures/Export")
        let summaries: [(String, ExportSummary)] = [
            ("library-export-failed", ExportSummary(total: 1, written: [], failures: failures, failedIDs: ["1"])),
            ("library-export-done", ExportSummary(total: 3, written: ["a.jpg", "b.jpg", "c.jpg"])),
            ("library-export-cancelled", ExportSummary(total: 24, written: ["a.jpg"], cancelled: true)),
        ]
        let states: [(String, ExportRun<ExportOptions>, ExportSummary?)] = [
            ("library-export", .editing(options), nil), ("library-exporting", .running(options, done: 1, total: 3), nil),
            ("library-export-error", .failed(options, "The export folder is gone."), nil),
        ] + summaries.map { ($0.0, .finished(options, $0.1.written), $0.1) }
        for scheme in [ColorScheme.light, .dark] {
            for (name, run, summary) in states {
                let sheet = LibraryExportSheet(
                    run: run, summary: summary, count: 3, preview: "IMG_0001.jpg · 2048 × 1365", writable: [.jpeg], exportHelp: nil,
                    presets: [], progressDelay: .zero)
                try snapshot(sheet, name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
            }
        }
    }

    @Test func sheetTexts() {
        #expect(LibraryExportSheet.title(1) == "Export 1 Photo" && LibraryExportSheet.title(3) == "Export 3 Photos")
        #expect(LibraryExportSheet.failureLines([FileFailure(path: "/Out/a.jpg", reason: "full")]) == ["a.jpg: full"])
        #expect(LibraryExportSheet.number(" 2048 ", in: 16...16384) == 2048)
        #expect(LibraryExportSheet.number("9", in: 16...16384) == nil && LibraryExportSheet.number("x", in: 0...100) == nil)
    }
}
