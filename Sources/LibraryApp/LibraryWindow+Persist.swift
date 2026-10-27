// LibraryWindow+Persist.swift: the persist area (persist PE-5). At launch it
// puts the catalog in `.loading` before the first await (so the window never
// shows a catalog that isn't the saved one), reads `catalog.json` off the main
// actor, decodes it and checks which photos' files are gone, then hands the
// result to the catalog's restore methods. A damaged file is set aside first;
// a newer one is left alone. After each change it waits 500 ms for more, then
// writes what `saveRequest()` asks for, one write at a time. On quit it
// writes synchronously. File > Show Catalog in Finder reveals the set-aside
// `catalog.json.bad`. The file work is here; every state change is a
// LibraryCatalog method. Backups (catalog-backup BK-5): the launch attaches
// `LibraryLaunch.backups`; a damaged file, once set aside, opens the newest
// good backup with its notice; each save that lands may keep a backup (at
// most hourly) and the quit flush forces one, all off the main actor but
// the flush.
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
    /// The file was damaged and set aside; the newest backup that decodes opens instead.
    case fromBackup(LibraryBackupFallback)
}

extension LibraryWindow {
    static let saveDelay = Duration.milliseconds(500)

    var persistMenu: LibraryMenu.Persist {
        LibraryMenu.Persist(
            showCatalogInFinder: enabled(model.catalogState == .damaged) { showCatalogInFinder() },
            dismissBackupNotice: enabled(model.backup.notice != nil) { model.dismissBackupNotice() })
    }

    /// Called once from the window's `.task`.
    func persistAreaLaunch() {
        model.beginRestore()
        let store = model.services.store
        let coding = model.services.coding
        let launch = LibraryLaunch(arguments: ProcessInfo.processInfo.arguments)
        let folder = (store as? CatalogStore)?.folder.path
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryFixtureBackups-\(UUID().uuidString)").path
        let offset = TimeZone.current.secondsFromGMT()
        Task {
            let (backups, result) = await Task.detached(priority: .userInitiated) { () async -> (LibraryBackups?, PersistLaunchResult) in
                let backups = launch.backups(catalogFolder: folder, scratch: scratch, now: Date())
                return (backups, await Self.readCatalog(store: store, coding: coding, backups: backups, utcOffset: offset))
            }.value
            model.attachBackups(backups)
            model.applyLaunch(result)
            // The file's photos replaced the catalog: drop the old photos' thumbnails too.
            switch result {
            case .restored(.some, _), .fromBackup: areas.thumbnails.store.clear()
            default: break
            }
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
        let backups = model.backup.backups
        defer { try? backups?.didSave(now: Date(), force: true) }
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
        let backups = model.backup.backups
        Task {
            let failure = await Task.detached(priority: .utility) { () -> LibraryError? in
                do {
                    try await store.write(coding.encode(request.photos))
                    // A backup that fails leaves the save as it was.
                    try? backups?.didSave(now: Date(), force: false)
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
    /// gone. A damaged file is set aside, then the newest good backup in
    /// `backups` opens instead; with none, the failure is returned.
    nonisolated static func readCatalog(store: any CatalogStoring, coding: any CatalogCoding,
                                        backups: LibraryBackups? = nil, utcOffset: Int = 0) async
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
            if let fallback = backups?.newestGood(damagedName: CatalogStore.setAsideName, utcOffset: utcOffset) {
                return .fromBackup(fallback)
            }
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
        case .fromBackup(let fallback):
            openBackup(fallback)
        }
    }
}
