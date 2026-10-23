// LibraryExportSnapshots.swift: the export sheet (export EX-6) editing, running,
// failed, done and cancelled, in Light and Dark: library-export, library-exporting,
// library-export-failed, library-export-done and library-export-cancelled. macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryExportSnapshots {
    @Test func exportStates() throws {
        let failures = [FileFailure(path: "/Out/IMG_0001.jpg", reason: "The folder is read-only.")]
        let states: [(String, ExportState)] = [
            ("library-export", .editing(ExportOptions(folder: "/Users/me/Pictures/Export"))),
            ("library-exporting", .running(done: 1, total: 3)),
            ("library-export-failed", .finished(ExportSummary(total: 1, written: [], failures: failures, failedIDs: ["1"]))),
            ("library-export-done", .finished(ExportSummary(total: 3, written: ["a.jpg", "b.jpg", "c.jpg"]))),
            ("library-export-cancelled", .finished(ExportSummary(total: 24, written: ["a.jpg"], cancelled: true))),
        ]
        for scheme in [ColorScheme.light, .dark] {
            for (name, state) in states {
                let sheet = LibraryExportSheet(
                    state: state, count: 3, preview: "IMG_0001.jpg · 2048 × 1365", writable: [.jpeg], exportHelp: nil,
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
