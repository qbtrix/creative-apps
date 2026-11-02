// LibraryDeleteRejects.swift: Photo > Delete Rejected Photos… (cull-finish).
// It moves the selected collection's rejects to the Trash through
// `services.trash`, takes them out of the catalog as one "Delete Rejects"
// step whose undo puts files and photos back, and remembers their paths so a
// re-import skips them (`excludedPaths`, LibraryImport). A move that fails
// keeps its photo and names it in `cullError`; the undo and redo of the step
// live in LibraryUndoAdapter. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One photo a Delete Rejects step took out: where it sat and where its file went (nil: no file, a sample).
public struct TrashedPhoto: Hashable, Sendable {
    public var photo: PhotoItem
    public var index: Int
    public var trashedPath: String?

    public init(photo: PhotoItem, index: Int, trashedPath: String?) {
        self.photo = photo; self.index = index; self.trashedPath = trashedPath
    }
}

extension LibraryCatalog {
    /// The selected collection's rejects, whatever the filter shows, in catalog order.
    public var deleteRejectsTargets: [PhotoItem] {
        collectionItems.filter { $0.flag == .reject }
    }

    /// "Delete 3 Rejected Photos…"; "Delete Rejected Photos…" with none.
    public var deleteRejectsTitle: String {
        switch deleteRejectsTargets.count {
        case 0: "Delete Rejected Photos…"
        case 1: "Delete 1 Rejected Photo…"
        case let count: "Delete \(count) Rejected Photos…"
        }
    }

    /// Why the item is off: no rejects in the collection, or the Trash's reason; nil when it can run.
    public var deleteRejectsHelp: String? {
        if deleteRejectsTargets.isEmpty {
            return "No rejected photos in \(selectedCollection?.name ?? "this collection")."
        }
        return services.unavailable["trash"]
    }

    /// The dialog's question: "Move 3 rejected photos to the Trash?"
    public var deleteRejectsMessage: String {
        let count = deleteRejectsTargets.count
        return count == 1 ? "Move 1 rejected photo to the Trash?" : "Move \(count) rejected photos to the Trash?"
    }

    /// Trash every target and take the moved ones out as one "Delete Rejects"
    /// step; any it couldn't move stay in the catalog and are named in
    /// `cullError` after how many moved. A sample (no file) leaves the catalog
    /// without a Trash call.
    public mutating func deleteRejects() {
        guard deleteRejectsHelp == nil else { return }
        let targets = Set(deleteRejectsTargets.map(\.id))
        var moved: [TrashedPhoto] = [], failed: [String] = []
        for (index, photo) in items.enumerated() where targets.contains(photo.id) {
            guard let path = photo.path else {
                moved.append(TrashedPhoto(photo: photo, index: index, trashedPath: nil))
                continue
            }
            do {
                moved.append(TrashedPhoto(photo: photo, index: index, trashedPath: try services.trash.moveToTrash(path)))
            } catch {
                failed.append(Self.trashFailure("Couldn't move", photo, error))
            }
        }
        guard !moved.isEmpty else {
            cullError = failed.first
            return
        }
        takeOutTrashed(moved)
        history.record("Delete Rejects", CatalogChange(photos: [], trashed: moved))
        history.open = false
        let count = moved.count == 1 ? "Moved 1 photo to the Trash." : "Moved \(moved.count) photos to the Trash."
        cullError = failed.isEmpty ? nil : ([count] + failed).joined(separator: " ")
    }

    /// "Couldn't move IMG_4: <reason>." for a Trash call on `photo` that threw `error`.
    static func trashFailure(_ verb: String, _ photo: PhotoItem, _ error: any Error) -> String {
        let reason = (error as? LibraryError)?.message ?? String(describing: error)
        let line = "\(verb) \(photo.name): \(reason)"
        return line.hasSuffix(".") ? line : line + "."
    }
}
