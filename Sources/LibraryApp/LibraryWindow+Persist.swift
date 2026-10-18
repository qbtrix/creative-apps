// LibraryWindow+Persist.swift: the persist area (persist PE-5). At launch it
// puts the catalog in `.loading` before the first await (so the window never
// shows a catalog that isn't the saved one), reads `catalog.json` off the main
// actor, decodes it and checks which photos' files are gone, then hands the
// result to the catalog's restore methods. A damaged file is set aside first;
// a newer one is left alone. After each change it waits 500 ms for more, then
// writes what `saveRequest()` asks for, one write at a time. On quit it
// writes synchronously. File > Show Catalog in Finder reveals the set-aside
// `catalog.json.bad`. The file work is here; every state change is a
// LibraryCatalog method.
import AppKit
import Foundation
import LibraryModel
import SwiftUI

final class PersistAreaState {
    /// The debounce before a save; a newer change cancels it.
    var pending: Task<Void, Never>?
    /// True while a write is under way, so writes never overlap.
    var isSaving = false
}

/// What the launch read found.
enum PersistLaunchResult: Sendable, Equatable {
    /// The file's photos (nil: there is no file) and the ids whose files are gone.
    case restored([PhotoItem]?, missing: Set<String>)
    case failed(LibraryError)
}

extension LibraryWindow {
    static let saveDelay = Duration.milliseconds(500)

    var persistMenu: LibraryMenu.Persist {
        LibraryMenu.Persist(showCatalogInFinder: enabled(model.catalogState == .damaged) { showCatalogInFinder() })
    }

    /// Called once from the window's `.task`.
    func persistAreaLaunch() {
        model.beginRestore()
        let store = model.services.store
        let coding = model.services.coding
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                await Self.readCatalog(store: store, coding: coding)
            }.value
            model.applyLaunch(result)
            // The file's photos replaced the catalog: drop the old photos' thumbnails too.
            if case .restored(.some, _) = result { areas.thumbnails.store.clear() }
        }
    }

    /// Called when `model.saveRevision` changes.
    func persistAreaChanged() {
        let state = areas.persist
        state.pending?.cancel()
        state.pending = Task {
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            save()
        }
    }

    /// Called when the app is about to quit: the one blocking write.
    func persistAreaFlush() {
        areas.persist.pending?.cancel()
        guard let request = model.saveRequest(), let store = model.services.store as? CatalogStore else { return }
        do {
            try store.writeNow(model.services.coding.encode(request.photos))
            model.didSave(revision: request.revision)
        } catch {
            model.failSave(error as? LibraryError ?? .invalid("Library couldn't save its catalog."))
        }
    }

    /// Writes what the catalog asks for off the main actor, then reports back;
    /// a change made during the write is saved right after it.
    private func save() {
        let state = areas.persist
        guard !state.isSaving, let request = model.saveRequest() else { return }
        state.isSaving = true
        let store = model.services.store
        let coding = model.services.coding
        Task {
            let failure = await Task.detached(priority: .utility) { () -> LibraryError? in
                do {
                    try await store.write(coding.encode(request.photos))
                    return nil
                } catch {
                    return error as? LibraryError ?? .invalid("Library couldn't save its catalog.")
                }
            }.value
            state.isSaving = false
            if let failure {
                model.failSave(failure)
            } else {
                model.didSave(revision: request.revision)
                save()
            }
        }
    }

    /// Reads and decodes the catalog and finds the photos whose files are
    /// gone. A damaged file is set aside before the failure is returned.
    nonisolated static func readCatalog(store: any CatalogStoring, coding: any CatalogCoding) async
        -> PersistLaunchResult {
        do {
            guard let data = try await store.read() else { return .restored(nil, missing: []) }
            let photos = try coding.decode(data)
            let missing = photos.filter { photo in
                photo.path.map { !FileManager.default.fileExists(atPath: $0) } ?? false
            }
            return .restored(photos, missing: Set(missing.map(\.id)))
        } catch LibraryError.damagedCatalog(let detail) {
            _ = try? await store.setAside()
            return .failed(.damagedCatalog(detail))
        } catch {
            return .failed(error as? LibraryError ?? .damagedCatalog(""))
        }
    }

    /// Reveals `catalog.json.bad` in the Finder.
    private func showCatalogInFinder() {
        guard let store = model.services.store as? CatalogStore else { return }
        let manager = FileManager.default
        let target = manager.fileExists(atPath: store.setAsideURL.path) ? store.setAsideURL : store.folder
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }
}

extension LibraryCatalog {
    /// Hands the launch read's result to the restore methods.
    mutating func applyLaunch(_ result: PersistLaunchResult) {
        switch result {
        case .restored(let photos, let missing):
            restore(photos)
            markMissing(missing)
        case .failed(let error):
            failRestore(error)
        }
    }
}
