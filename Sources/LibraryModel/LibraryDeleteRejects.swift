// LibraryDeleteRejects.swift: Photo > Delete Rejected Photos… (cull-finish).
// It moves the selected collection's rejects to the Trash through
// `services.trash`, takes them out of the catalog as one "Delete Rejects"
// step whose undo puts files and photos back, and remembers their paths so a
// re-import skips them. DR-1 holds the stubs: the targets, title and
// message are real; `deleteRejectsHelp` disables the item until DR-6 gives
// `deleteRejects` its body. Linux-safe.
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
        return services.unavailable["trash"] ?? "Delete Rejects isn't connected yet (cull-finish)."
    }

    /// The dialog's question: "Move 3 rejected photos to the Trash?"
    public var deleteRejectsMessage: String {
        let count = deleteRejectsTargets.count
        return count == 1 ? "Move 1 rejected photo to the Trash?" : "Move \(count) rejected photos to the Trash?"
    }

    /// Trash every target and take the moved ones out as one "Delete Rejects"
    /// step; the status line says how many and names any it couldn't move,
    /// which stay in the catalog. DR-1: does nothing until DR-6.
    public mutating func deleteRejects() {
        guard deleteRejectsHelp == nil else { return }
    }
}
