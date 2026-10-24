// FlareExportPackSnapshots.swift: MP4 and GIF in the export sheet (export-pack FV-2 and FV-5;
// docs/blueprints/flare/features/export-pack.md, Screens and states), the adapter's content view
// (`FlareExportSheetAdapter.sheet`) on `bounce` with the fakes, each state reached through the Model's public
// methods: GIF at its defaults (light and dark: the shared Size row, Frame rate at the scene's rate, Loop forever on,
// no scale chips or Transparent checkbox), MP4 at 0.5x and 24 fps (no Loop row) and a GIF run at 24 of its 48
// frames (FV-5). Each test checks the Model state it shows first. flare-export-gif-*.png, flare-export-mp4-dark.png,
// flare-export-running-gif-dark.png. macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareExportPackSnapshots {
    /// `bounce` on the fakes with the sheet open on `format`.
    private func opened(_ format: ExportFormat) -> FlareWorkspace {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        let open = model.openExport()
        #expect(open)
        model.setExportFormat(format)
        return model
    }

    private func shoot(_ model: FlareWorkspace, _ name: String, scheme: ColorScheme = .dark) throws {
        try snapshot(FlareExportSheetAdapter(model: model, perform: { _ in }).sheet, name: name, scheme: scheme)
    }

    @Test func gif() throws {
        let model = opened(.gif)
        let options = try #require(model.exportingOptions)
        #expect(options.format == .gif && options.size == .scale(1) && options.loop && options.fps == nil)
        #expect(model.exportProblem == nil && model.exportFileCount == 1)
        #expect(FlareExportSheetAdapter.formats.map(\.id).suffix(2) == ["mp4", "gif"])
        try shoot(model, "flare-export-gif-light", scheme: .light)
        try shoot(model, "flare-export-gif-dark")
    }

    @Test func mp4() throws {
        var model = opened(.mp4)
        model.setExportSize(.scale(0.5))
        model.setExportFrameRate(24)
        #expect(model.exportingOptions?.sheetScale == 0.5 && model.exportFrameRate == 24)
        #expect(model.exportProblem == nil)
        try shoot(model, "flare-export-mp4-dark")
    }

    @Test func running() throws {
        var model = opened(.gif)
        let started = model.startExport()
        #expect(started)
        model.exportProgressed(0.5)
        let options = try #require(model.exportingOptions)
        #expect(model.exportState == .running(options, done: 24, total: 48))
        try shoot(model, "flare-export-running-gif-dark")
    }
}
