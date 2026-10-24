// LibraryWindow+Import.swift: the import area (import IM-6). File > Import
// Folder… takes `-LibraryImportFolder` or a folder from the open panel (a
// folder dropped on the empty catalog skips the panel), with the copy choice
// from `-LibraryImportCopyTo` or the panel's accessory and a second panel for
// the copy folder (catalog-files LC-7), runs `file.import-folder` on the
// catalog, runs the importer off the main actor and
// hands its progress, batches and result back to the catalog in order.
// `-LibraryImportOnLaunch` imports once, as soon as the catalog has loaded.
import AppKit
import Foundation
import LibraryModel
import SuiteKernel
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
            importDropped: enabled(model.importHelp == nil) { (folder: String) in
                importFolder(folder, copy: ImportCopyOptions())
            },
            importHelp: model.importHelp,
            showImportFailures: enabled(showFailuresWhy == nil) { showImportFailures() },
            dismissImportNotice: act(.dismissImportNotice))
    }

    /// Why `notice.show-failures` can't run on the window's catalog, nil when it can.
    private var showFailuresWhy: String? {
        LibraryCatalog.catalog.availability("notice.show-failures", on: model).why
    }

    /// The notice's Show or Hide: the catalog's `notice.show-failures`, which flips
    /// whether the failures are listed. Its refusal is the disabled state's help.
    private func showImportFailures() {
        _ = try? LibraryCatalog.catalog.run("notice.show-failures", params: .object([:]), on: &model)
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

    /// The launch folder and copy choice, else the ones the open panels pick; nothing when one is cancelled.
    func startImport() {
        let launch = areas.imports.launch
        if let folder = launch.importFolder { return importFolder(folder, copy: launch.importCopy) }
        guard let picked = Self.chooseImportFolder() else { return }
        importFolder(picked.folder, copy: picked.copy)
    }

    /// `file.import-folder`, the importer (copying when `copy` says so) off the main actor, then
    /// `finishImport` or `failImport`.
    private func importFolder(_ folder: String, copy: ImportCopyOptions) {
        let options = ImportOptions(folder: folder, copyTo: copy.copyTo, byDate: copy.byDate)
        guard let params = try? JSONValue(encoding: options),
              (try? LibraryCatalog.catalog.run("file.import-folder", params: params, on: &model)) != nil else { return }
        let known = model.importKnownIDs
        let name = URL(fileURLWithPath: folder).lastPathComponent
        let importer = model.services.importer.copying(model.importCopy)
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

    /// The open panel, folders only, with the copy choice; then, when copying, a panel for the copy folder.
    /// Nil when either is cancelled.
    private static func chooseImportFolder() -> (folder: String, copy: ImportCopyOptions)? {
        let folderPanel = { (prompt: String) -> NSOpenPanel in
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = prompt
            return panel
        }
        let choice = ImportCopyChoice()
        let panel = folderPanel("Import")
        // Add in place or copy to a folder (catalog-files LC-3, LibraryImportOptions.swift).
        panel.accessoryView = NSHostingView(rootView: LibraryImportOptions(choice: choice))
        panel.isAccessoryViewDisclosed = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        var copy = choice.options
        if let start = copy.copyTo {
            let destination = folderPanel("Copy Here")
            destination.message = "Choose the folder to copy the photos into."
            destination.canCreateDirectories = true
            destination.directoryURL = URL(fileURLWithPath: start, isDirectory: true)
            guard destination.runModal() == .OK, let target = destination.url else { return nil }
            copy.copyTo = target.path(percentEncoded: false)
        }
        return (url.path(percentEncoded: false), copy)
    }
}
