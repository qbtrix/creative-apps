// LibraryExportSnapshots.swift: the export sheet (export EX-6) on SuiteUI's
// SuiteExportSheet (#5270) editing, running, failed, done and cancelled, in
// Light and Dark: library-export, library-exporting, library-export-failed,
// library-export-done and library-export-cancelled. The readout test pins what
// the shared sheet shows for each state: Library's title, its summary words as
// the line, "Exporting 2 of 3" while the second photo writes, and Try Again
// only after a photo failed. macOS only.
import LibraryModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryExportSnapshots {
    static let options = ExportOptions(folder: "/Users/me/Pictures/Export")
    static let failures = [FileFailure(path: "/Out/IMG_0001.jpg", reason: "The folder is read-only.")]
    static let failed = ExportSummary(total: 1, written: [], failures: failures, failedIDs: ["1"])
    static let done = ExportSummary(total: 3, written: ["a.jpg", "b.jpg", "c.jpg"])
    static let cancelled = ExportSummary(total: 24, written: ["a.jpg"], cancelled: true)

    @Test func exportStates() throws {
        let states: [(String, ExportRun<ExportOptions>, ExportSummary?)] = [
            ("library-export", .editing(Self.options), nil),
            ("library-exporting", .running(Self.options, done: 1, total: 3), nil),
            ("library-export-failed", .finished(Self.options, []), Self.failed),
            ("library-export-done", .finished(Self.options, Self.done.written), Self.done),
            ("library-export-cancelled", .finished(Self.options, Self.cancelled.written), Self.cancelled),
        ]
        for scheme in [ColorScheme.light, .dark] {
            for (name, run, summary) in states {
                let sheet = LibraryExportSheetAdapter(
                    run: run, summary: summary, count: 3, preview: "IMG_0001.jpg · 2048 × 1365", writable: [.jpeg],
                    exportHelp: nil, presets: [])
                try snapshot(sheet, name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
            }
        }
    }

    @Test func readoutFollowsTheRunAndSummary() {
        let formats = LibraryExportSheetAdapter.formats(writable: [.jpeg, .png])
        #expect(formats.map(\.id) == ["JPEG", "PNG"] && formats.allSatisfy { !$0.hasQuality })
        func readout(_ run: ExportRun<ExportOptions>, _ summary: ExportSummary? = nil) -> ExportSheetRows {
            LibraryExportSheetAdapter.readout(run, summary: summary, formats: formats)
        }
        let editing = readout(.editing(Self.options))
        #expect(editing.rows == [.format("JPEG")] && editing.editable && editing.line == nil)
        #expect(editing.actions(canTryAgain: false, canReveal: false) == [.cancel, .start])
        let running = readout(.running(Self.options, done: 1, total: 3))
        #expect(!running.editable && running.progress?.text == "Exporting 2 of 3" && running.line == nil)
        #expect(readout(.running(Self.options, done: 3, total: 3)).progress?.text == "Exporting 3 of 3")
        let failed = readout(.finished(Self.options, []), Self.failed)
        #expect(failed.line == .failed("1 photo couldn't be exported.") && failed.progress == nil)
        #expect(failed.actions(canTryAgain: true, canReveal: false) == [.tryAgain, .dismiss, .start])
        #expect(readout(.finished(Self.options, Self.done.written), Self.done).line == .finished("Exported 3 photos."))
        let stopped = readout(.finished(Self.options, ["a.jpg"]), Self.cancelled)
        #expect(stopped.line == .finished("Exported 1 of 24. Export was cancelled."))
        #expect(readout(.failed(Self.options, "The disk is full.")).line == .failed("The disk is full."))
    }

    @Test func sheetTexts() {
        typealias Sheet = LibraryExportSheetAdapter
        #expect(Sheet.title(1) == "Export 1 Photo" && Sheet.title(3) == "Export 3 Photos")
        #expect(Sheet.failureLines([FileFailure(path: "/Out/a.jpg", reason: "full")]) == ["a.jpg: full"])
        #expect(Sheet.number(" 2048 ", in: 16...16384) == 2048)
        #expect(Sheet.number("9", in: 16...16384) == nil && Sheet.number("x", in: 0...100) == nil)
    }
}
