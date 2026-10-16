// LibraryWindow+Import.swift: the import area (import IM-6). File > Import
// Folder… takes `-LibraryImportFolder` or a folder from the open panel,
// begins the import on the catalog, runs the importer off the main actor and
// hands its progress, batches and result back to the catalog in order.
// `-LibraryImportOnLaunch` imports once, as soon as the catalog has loaded.
import AppKit
import Foundation
import LibraryModel
import SwiftUI

final class ImportAreaState {
    /// The launch arguments' import folder and import-on-launch switch.
    let launch = LibraryLaunch(arguments: ProcessInfo.processInfo.arguments)
    /// Set once the launch import has started, so it runs once per window.
    var didLaunchImport = false
}

/// What the importer reports, in the order it reports it.
private enum ImportEvent: Sendable {
    case progress(ImportProgress)
    case added([PhotoItem])
    case finished(ImportResult)
    case failed(LibraryError)
}

extension LibraryWindow {
    var fileMenu: LibraryMenu.File {
        LibraryMenu.File(
            importFolder: enabled(model.importHelp == nil) { startImport() },
            importHelp: model.importHelp,
            dismissImportNotice: enabled(model.importNotice != nil) { model.dismissImportNotice() })
    }

    /// Called once from the window's `.task`.
    func importAreaLaunch() { launchImportIfReady() }

    /// Called when `model.catalogState` changes (the restore finished).
    func importAreaCatalogReady() { launchImportIfReady() }

    /// `-LibraryImportOnLaunch`: imports once the catalog has left `.loading`.
    private func launchImportIfReady() {
        let state = areas.imports
        guard state.launch.importOnLaunch, !state.didLaunchImport, model.catalogState != .loading else { return }
        state.didLaunchImport = true
        startImport()
    }

    /// The launch folder, else the one the open panel picks; nothing when it is cancelled.
    func startImport() {
        guard let folder = areas.imports.launch.importFolder ?? Self.chooseImportFolder() else { return }
        importFolder(folder)
    }

    /// `beginImport`, the importer off the main actor, then `finishImport` or `failImport`.
    private func importFolder(_ folder: String) {
        guard let known = model.beginImport() else { return }
        let name = URL(fileURLWithPath: folder).lastPathComponent
        let importer = model.services.importer
        let (events, sink) = AsyncStream<ImportEvent>.makeStream()
        Task.detached(priority: .userInitiated) {
            do {
                let result = try await importer.importFolder(
                    folder, known: known,
                    progress: { sink.yield(.progress($0)) },
                    added: { sink.yield(.added($0)) })
                sink.yield(.finished(result))
            } catch {
                sink.yield(.failed(error as? LibraryError ?? .invalid("Library couldn't import \(name).")))
            }
            sink.finish()
        }
        // On the main actor: one stream keeps the batches before the result.
        Task {
            for await event in events {
                switch event {
                case .progress(let progress): model.showImportProgress(progress)
                case .added(let batch): model.appendImported(batch)
                case .finished(let result): model.finishImport(result, folder: name)
                case .failed(let error): model.failImport(error, folder: name)
                }
            }
        }
    }

    /// The open panel, folders only; nil when cancelled.
    private static func chooseImportFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path(percentEncoded: false)
    }
}
