// LibraryWindow+Export.swift: the export area (export EX-6): File > Export…
// opens the sheet; Export plans on the catalog and runs ExportRunner off the
// main actor, its progress and summary streamed back as the import area does.
// The presets and the last options live in `export-presets.json` beside the
// catalog file (EX-11): read when the sheet first opens, written whenever
// either changes, so they come back after a relaunch.
import AppKit
import Foundation
import LibraryModel
import SuiteModel
import SwiftUI

/// The last options (offered again), the presets, and the running export.
@Observable final class ExportAreaState {
    let launch = LibraryLaunch(arguments: ProcessInfo.processInfo.arguments)
    let store = ExportPresetStore()
    var last: ExportOptions?
    var presets: [ExportPreset] = ExportPresets.builtIns
    var loaded = false
    var run: Task<ExportSummary, Never>?
}

/// `export-presets.json` in the catalog's folder, through SuiteModel's FileStore
/// (an atomic replace). A missing or damaged file reads as the built-ins and no
/// last options; a failed write is dropped, since presets never block an export.
struct ExportPresetStore {
    static let fileName = "export-presets.json"
    let files = FileStore(folder: CatalogStore().folder.path(percentEncoded: false))

    func read() -> ExportPresetFile { ExportPresets.decode(try? files.readData(Self.fileName)) }

    func write(_ file: ExportPresetFile) {
        try? FileManager.default.createDirectory(atPath: files.folder, withIntermediateDirectories: true)
        try? files.writeData(Self.fileName, ExportPresets.encode(file))
    }
}

extension LibraryWindow {
    var exportMenu: LibraryMenu.Export {
        let export: LibraryMenu.Action? = enabled(model.exportHelp == nil) { () -> Void in openExportSheet() }
        return LibraryMenu.Export(export: export, exportHelp: model.exportHelp)
    }

    /// The sheet for the current export state, every control wired to the catalog.
    var exportSheet: LibraryExportSheet {
        let options: ExportOptions? = LibraryExportSheet.options(model.exportState)
        let editing = options != nil
        var actions = LibraryExportSheet.Actions()
        actions.setOptions = enabled(editing) { (next: ExportOptions) -> Void in model.setExportOptions(next) }
        actions.chooseFolder = enabled(editing) { () -> Void in exportChooseFolder() }
        actions.export = enabled(editing) { () -> Void in startExport() }
        actions.cancel = enabled(model.exportState.isRunning) { () -> Void in cancelExport() }
        actions.retry = enabled(areas.export.last != nil) { () -> Void in retryExport() }
        actions.close = enabled(!model.exportState.isRunning) { () -> Void in closeExportSheet() }
        actions.showInFinder = enabled(!model.exportState.isRunning) { () -> Void in exportShowInFinder() }
        let presetsReady: Bool = editing && ExportPresets.unavailable == nil
        actions.applyPreset = enabled(presetsReady) { (preset: ExportPreset) -> Void in
            guard let current = LibraryExportSheet.options(model.exportState) else { return }
            model.setExportOptions(preset.applied(to: current))
        }
        actions.savePreset = enabled(presetsReady) { (name: String) -> Void in
            guard let current = LibraryExportSheet.options(model.exportState) else { return }
            areas.export.presets = ExportPresets.adding(ExportPreset(name: name, options: current), to: areas.export.presets)
            saveExportPresets()
        }
        let help: String? = model.services.unavailable["exporter"] ?? options?.naming.help
        return LibraryExportSheet(
            state: model.exportState, count: model.exportTargets.count, preview: model.exportPreview,
            writable: JPEGWriter.writableFormats(), exportHelp: help, presets: areas.export.presets, actions: actions)
    }

    /// The sheet in the launch folder, the last one, or Pictures; the stored
    /// presets and last options are read the first time.
    private func openExportSheet() {
        let state = areas.export
        if !state.loaded {
            let file = state.store.read()
            (state.presets, state.last, state.loaded) = (file.presets, state.last ?? file.last, true)
        }
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        let folder = state.launch.exportTo ?? state.last?.folder ?? pictures?.path(percentEncoded: false) ?? NSHomeDirectory()
        _ = model.beginExport(folder: folder, last: state.last)
    }

    private func startExport() {
        guard let options = LibraryExportSheet.options(model.exportState) else { return }
        areas.export.last = options
        saveExportPresets()
        planExport(options) { (names: Set<String>) -> ExportPlan? in model.exportPlan(existingNames: names) }
    }

    /// Try Again: the failed photos only, under the last options.
    private func retryExport() {
        guard let options = areas.export.last else { return }
        planExport(options) { (names: Set<String>) -> ExportPlan? in model.retryExport(options: options, existingNames: names) }
    }

    /// Lists the folder, then plans and runs. An unreadable folder plans with no
    /// names; each write then fails on its own.
    private func planExport(_ options: ExportOptions, _ plan: @escaping @MainActor (Set<String>) -> ExportPlan?) {
        let writer = model.services.writer
        Task {
            let existing = (try? await writer.existingNames(in: options.folder)) ?? []
            if let planned = plan(existing) { runExport(planned) }
        }
    }

    private func runExport(_ plan: ExportPlan) {
        let photos = Dictionary(model.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let exporter = model.services.exporter
        let writer = model.services.writer
        let sidecars = JPEGWriter()
        let total = plan.items.count
        let (events, sink) = AsyncStream<Int>.makeStream()
        let run = Task.detached(priority: .userInitiated) { () -> ExportSummary in
            let summary = await ExportRunner.run(
                plan, photos: photos, exporter: exporter, writer: writer,
                writeSidecar: { try await sidecars.writeSidecar($0, folder: $1, fileName: $2) },
                progress: { (done: Int) -> Void in sink.yield(done) })
            sink.finish()
            return summary
        }
        areas.export.run = run
        Task {
            for await done in events { model.showExportProgress(done: done, total: total) }
            let summary = await run.value
            model.finishExport(summary)
            areas.export.run = nil
        }
    }

    /// Cancel or Done: options still being edited become the last ones.
    private func closeExportSheet() {
        if let options = LibraryExportSheet.options(model.exportState) {
            areas.export.last = options
            saveExportPresets()
        }
        model.closeExport()
    }

    private func saveExportPresets() {
        let state = areas.export
        guard state.loaded else { return }
        state.store.write(ExportPresetFile(presets: state.presets, last: state.last))
    }

    private func cancelExport() { if model.cancelExport() { areas.export.run?.cancel() } }

    /// Choose…: the open panel, folders only; the editing options take its folder.
    private func exportChooseFolder() {
        guard var options = LibraryExportSheet.options(model.exportState) else { return }
        let panel = NSOpenPanel()
        (panel.canChooseFiles, panel.canChooseDirectories, panel.canCreateDirectories) = (false, true, true)
        panel.directoryURL = URL(fileURLWithPath: options.folder)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        options.folder = url.path(percentEncoded: false)
        model.setExportOptions(options)
    }

    /// Show in Finder: the written files selected, else their folder.
    private func exportShowInFinder() {
        guard case .finished(let summary) = model.exportState, let folder = areas.export.last?.folder else { return }
        let base = URL(fileURLWithPath: folder)
        let files = summary.written.map { base.appendingPathComponent($0) }
        NSWorkspace.shared.activateFileViewerSelecting(files.isEmpty ? [base] : files)
    }
}

private extension ExportState {
    var isRunning: Bool { if case .running = self { return true }; return false }
}
