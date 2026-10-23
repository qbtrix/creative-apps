// FlareExportSnapshots.swift: the export sheet (flare-export FX-5;
// docs/blueprints/flare/features/flare-export.md, Screens and states), the
// adapter's content view (`FlareExportSheetAdapter.sheet`) on `showcase` with
// the fakes, each state reached through the Model's public methods: SVG frame
// editing (light and dark), the PNG sequence 0...12 step 2 (7 files), To at 90
// (Export refused), running at 3 of 7, finished ("Exported 7 files.") and
// failed (scene-1.svg already in Exports). Each test checks the Model state it
// shows first. Under the format and size rows each shows Flare's options rows
// (FlareExportOptionRows): the Frame or From, To and Step rows, the 1x and 2x
// chips, Transparent background, the three warnings, and while editing the
// file count or, at To 90, the problem line "Frames 0–90 aren't all in the
// scene."; finished reads "Exported 7 files.". flare-export-*.png. macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareExportSnapshots {
    /// `showcase` on the fakes with the sheet open on its SVG frame defaults.
    private func opened() -> FlareWorkspace {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "showcase"]))
        let open = model.openExport()
        #expect(open)
        return model
    }

    /// The PNG sequence 0...12 step 2: 7 files.
    private func sevenPNGs() -> FlareWorkspace {
        var model = opened()
        model.setExportFormat(.pngSequence)
        model.setExportFrames(0...12)
        model.setExportStep(2)
        #expect(model.exportFileCount == 7 && model.exportProblem == nil)
        return model
    }

    /// The seven-file run started and at 3 of 7.
    private func running() -> FlareWorkspace {
        var model = sevenPNGs()
        let started = model.startExport()
        #expect(started)
        model.exportProgressed(0.5)
        return model
    }

    private func shoot(_ model: FlareWorkspace, _ name: String, scheme: ColorScheme = .dark) throws {
        try snapshot(FlareExportSheetAdapter(model: model, perform: { _ in }).sheet, name: name, scheme: scheme)
    }

    @Test func svg() throws {
        let model = opened()
        #expect(model.exportingOptions?.format == .svgFrame)
        #expect(model.exportProblem == nil && model.exportFileCount == 1)
        let options = try #require(model.exportingOptions)
        #expect(model.exportWarnings(options).count == 3)
        try shoot(model, "flare-export-svg-light", scheme: .light)
        try shoot(model, "flare-export-svg-dark")
    }

    @Test func png() throws {
        let model = sevenPNGs()
        #expect(model.exportingOptions?.frames == 0...12 && model.exportingOptions?.step == 2)
        try shoot(model, "flare-export-png-dark")
    }

    @Test func problem() throws {
        var model = sevenPNGs()
        model.setExportFrames(0...90)
        #expect(model.exportProblem == "Frames 0–90 aren't all in the scene.")
        let started = model.startExport()
        #expect(model.exportFileCount == 0 && !started)
        try shoot(model, "flare-export-problem-dark")
    }

    @Test func progress() throws {
        let model = running()
        guard case .running(_, let done, let total) = model.exportState else {
            Issue.record("the run isn't running: \(model.exportState)")
            return
        }
        #expect(done == 3 && total == 7)
        try shoot(model, "flare-export-running-dark")
    }

    @Test func finished() throws {
        var model = running()
        model.endExport(.success((0...6).map { "frame_\(String(format: "%04d", $0 * 2)).png" }))
        #expect(model.exportSummary == "Exported 7 files.")
        try shoot(model, "flare-export-finished-dark")
    }

    @Test func failed() throws {
        var model = opened()
        let started = model.startExport()
        #expect(started)
        model.endExport(.failure(ExportWriteRefusal.alreadyThere(name: "scene-1.svg", folder: "Exports")))
        guard case .failed(_, let sentence) = model.exportState else {
            Issue.record("the run didn't fail: \(model.exportState)")
            return
        }
        #expect(sentence == "scene-1.svg is already in Exports. Choose another folder.")
        try shoot(model, "flare-export-failed-dark")
    }
}
