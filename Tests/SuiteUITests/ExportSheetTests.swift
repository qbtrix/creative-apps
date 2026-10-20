// ExportSheetTests.swift: ExportSheetRows follows the kernel's ExportRun, and
// the gallery's fake run climbs to 10 of 10 and finishes (EK-30). The sheet's
// controls take the host's prefix (#1989): format chips, the actions each run
// state offers, and a host-supplied options view, all registered in
// `suite.controls` once hosted. macOS only.
import AppKit
import SuiteKernel
import SwiftUI
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

    /// A host with its own scale control drops the Size row, so the sheet never shows two scales.
    @Test func aHostCanLeaveOutTheSizeRow() {
        let jpeg = ExportPick(format: "jpeg", scale: 2, quality: 0.6)
        let run = ExportRun<ExportPick>.editing(jpeg)
        let rows = ExportSheetRows(run, formats: GalleryEditorKernelChrome.formats, showsSize: false) { $0 }
        #expect(rows.rows == [.format("jpeg"), .quality(0.6)] && rows.editable)
    }

    @Test func idsTakeTheHostPrefix() {
        let ids = ExportSheetIDs("flare.export")
        let formats = ["svgFrame", "lottie", "pngSequence"].map(ids.format)
        #expect(formats == ["flare.export.format.svgFrame", "flare.export.format.lottie", "flare.export.format.pngSequence"])
        let actions = ExportSheetAction.allCases.map(ids.id)
        #expect(actions == ["flare.export.tryAgain", "flare.export.reveal", "flare.export.cancel", "flare.export.dismiss", "flare.export.start"])
        #expect(ExportSheetIDs().start == "suite.export.start" && ExportSheetIDs().progress == "suite.export.progress")
    }

    @Test func actionsFollowTheRun() {
        let png = ExportPick(format: "png")
        #expect(rows(.editing(png)).actions(canTryAgain: true, canReveal: true) == [.cancel, .start])
        #expect(rows(.running(png, done: 1, total: 3)).actions(canTryAgain: true, canReveal: true) == [.cancel, .start])
        #expect(rows(.finished(png, ["a.png"])).actions(canTryAgain: true, canReveal: true) == [.reveal, .dismiss, .start])
        #expect(rows(.finished(png, ["a.png"])).actions(canTryAgain: true, canReveal: false) == [.dismiss, .start])
        #expect(rows(.failed(png, "No.")).actions(canTryAgain: true, canReveal: true) == [.tryAgain, .dismiss, .start])
        #expect(rows(.failed(png, "No.")).actions(canTryAgain: false, canReveal: true) == [.dismiss, .start])
    }

    /// A sheet with prefix `flare.export` registers its chips' group, its actions and the host's options row.
    @MainActor @Test func hostedSheetRegistersTheHostsIDs() {
        let formats = ["svgFrame", "lottie", "pngSequence"].map { FormatChoice(id: $0, name: $0, hasQuality: false) }
        let pick = ExportPick(format: "svgFrame")
        let cases: [(ExportRun<ExportPick>, [String])] = [
            (.editing(pick), ["flare.export.cancel", "flare.export.start", "flare.export.format", "flare.export.frame"]),
            (.finished(pick, ["scene-1.svg"]), ["flare.export.dismiss", "flare.export.reveal", "flare.export.start"]),
            (.failed(pick, "scene-1.svg is already in Exports."), ["flare.export.dismiss", "flare.export.tryAgain"]),
        ]
        for (run, expected) in cases {
            let store = SuiteControlStore()
            let sheet = SuiteExportSheet(
                ExportSheetRows(run, formats: formats) { $0 }, formats: formats, idPrefix: "flare.export",
                onFormat: { _ in }, onScale: { _ in }, onQuality: { _ in }, onExport: {}, onClose: {},
                onTryAgain: {}, onReveal: {}
            ) {
                Text(verbatim: "Frame").suiteControl(id: "flare.export.frame", enabled: true, reason: nil)
            }
            host(sheet.environment(\.suiteControlStore, store))
            let ids = Set(store.inventory.document().controls.map(\.id))
            for id in expected { #expect(ids.contains(id), "\(run): \(id) missing from \(ids.sorted())") }
            #expect(store.inventory.violations().isEmpty, "\(run): \(store.inventory.violations())")
        }
    }

    @MainActor private func host(_ view: some View) {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
    }
}
