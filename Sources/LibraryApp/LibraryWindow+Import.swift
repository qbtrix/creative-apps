// LibraryWindow+Import.swift: the import area (import IM-6). File > Import
// Folder… takes `-LibraryImportFolder` or a folder from the open panel (a
// folder dropped on the empty catalog skips the panel),
// begins the import on the catalog, runs the importer off the main actor and
// hands its progress, batches and result back to the catalog in order.
// `-LibraryImportOnLaunch` imports once, as soon as the catalog has loaded.
// Below it, the file flow (LF-4): suite recents, a drop's hand-offs and the loupe's drag-out.
import AppKit
import Foundation
import LibraryModel
import SuiteKernel
import SuiteModel
import SuiteShell
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
            importDropped: enabled(model.importHelp == nil) { (folder: String) in importFolder(folder) },
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

// The file flow (file-flow LF-4): each photo opened in the loupe is noted once in the suite's shared recents
// through SuiteDocumentsBridge, the way Flare notes its opens, and the catalog's Recent Files read that list back;
// a drop's hand-offs go to their apps through the bridge; the loupe drags its photo out as the file and a PNG.
extension LibraryWindow {
    #if DEBUG
    /// A test's bridge on fake services; nil uses the app's.
    @MainActor static var bridgeOverride: SuiteDocumentsBridge?
    /// The shown window's catalog, drop, loupe open and drag-out, for LibraryFileFlowLiveTests.
    @MainActor static var shownModel: LibraryCatalog?
    @MainActor static var shownDrop: (([DropAction]) -> Void)?
    @MainActor static var shownOpen: ((String) -> Void)?
    @MainActor static var shownDragItems: (() -> [SuiteClipItem])?
    #endif

    /// The bridge the window notes in and hands off through.
    @MainActor static var bridge: SuiteDocumentsBridge {
        #if DEBUG
        if let bridgeOverride { return bridgeOverride }
        #endif
        return LibraryShell.bridge
    }

    /// Called from the body: publishes the test hooks (DEBUG only).
    func fileFlowShown() {
        #if DEBUG
        Self.shownModel = model
        Self.shownDrop = { fileFlowDrop($0) }
        Self.shownOpen = { model.open($0) }
        Self.shownDragItems = { [model] in Self.loupeDragItems(model) }
        #endif
    }

    /// Called when the loupe's photo or the mode changes: notes a new loupe open once, then reads the list back.
    func fileFlowLoupeChanged() {
        guard let ref = model.takeLoupeOpen() else { return }
        let bridge = Self.bridge
        Task {
            await bridge.note(ref, .opened)
            let recents = bridge.recents(for: .library)
            if recents != model.recentFiles { model.updateFileFlow(recents: recents) }
        }
    }

    /// A drop: the catalog imports what it places; each other app's document goes to that app.
    func fileFlowDrop(_ actions: [DropAction]) {
        try? model.perform(actions)
        let handOffs: [DropAction] = model.takeFileRequests().compactMap {
            if case .handOff(let path, let app) = $0 { .handOff(path: path, app: app) } else { nil }
        }
        guard !handOffs.isEmpty else { return }
        let bridge = Self.bridge
        Task { await bridge.handOff(handOffs) }
    }

    /// What dragging the loupe's photo carries: its file, then a PNG of it at most 2048 px on its long side
    /// (just the file when it can't be decoded).
    nonisolated static func loupeDragItems(_ model: LibraryCatalog) -> [SuiteClipItem] {
        guard let path = model.loupeSuiteRef?.path, let data = FileManager.default.contents(atPath: path),
              let image = try? SuiteImageIO.uprightImage(data, longestSide: 2048),
              let png = try? SuiteImageIO.encode(image, as: .png, quality: nil)
        else { return model.loupeDragItems(png: nil, size: nil) }
        return model.loupeDragItems(png: png, size: PixelSize(width: image.width, height: image.height))
    }
}

extension View {
    /// The loupe's drag-out, a placeholder on its readout: the canvas's own drag (pan and crop) would swallow one
    /// on the picture. Dragging a grid cell out waits for SuiteUI's per-cell drag source (#3928).
    func libraryDragOut(_ model: LibraryCatalog) -> some View {
        suiteDraggable(SuitePasteboardCoding()) { LibraryWindow.loupeDragItems(model) }
    }
}
