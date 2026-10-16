// LibraryCulling.swift: rating, flagging and labelling photos from the keys,
// the menu and the inspector. A change goes to the loupe's photo in the
// loupe, else to the selection, through `services.culling`, and is one undo
// step named for the change. A refused change sets `cullError` and leaves no
// trace. With Auto Advance on, a rating or a flag in the loupe moves the loupe
// to the photo `services.culling.advance` picks, or back to the grid when
// nothing is left to show; a label, the grid and undo never move it (CU-3,
// #426). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension LibraryCatalog {
    /// The loupe photo in the loupe, else the selection; empty: nothing to cull.
    /// Reads `order`, not `loupeItem`, so a cull on 10,000 photos stays cheap.
    public var cullTargets: Set<String> {
        if mode == .loupe { return focusedItemID.map { order.contains($0) ? [$0] : [] } ?? [] }
        return selection
    }

    /// "Select a photo to rate it." with no targets, else nil.
    public var cullHelp: String? {
        cullTargets.isEmpty ? "Select a photo to rate it." : nil
    }

    /// Applies `change` to `cullTargets` through `services.culling` as one
    /// undo step named `change.undoName`. A throw sets `cullError` and
    /// changes nothing; success clears it. No targets: does nothing. In the
    /// loupe, with `advance` and `autoAdvance` on, a rating or a flag then
    /// moves the loupe on; the grid's selection never moves.
    public mutating func cull(_ change: CullChange, advance: Bool = true) {
        let ids = cullTargets
        guard !ids.isEmpty else { return }
        let beforeOrder = order  // a copy-on-write share: no O(n) work
        let next: [PhotoItem]
        do {
            next = try services.culling.apply(change, to: ids, in: targetItems(ids))
        } catch {
            cullError = (error as? LibraryError)?.message ?? String(describing: error)
            return
        }
        let changed = Dictionary(
            next.filter { ids.contains($0.id) }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        recordEdit(change.undoName, ids: ids) { photo in
            if let updated = changed[photo.id] { photo = updated }
        }
        cullError = nil
        if advance, autoAdvance, change.advancesLoupe { advanceLoupe(before: beforeOrder) }
    }

    /// The photos with `ids`, the only ones the rules change. One id (the
    /// loupe, a single selection) is found by a plain scan, several through
    /// the set: hashing all 10,000 ids would eat the 10 ms budget.
    private func targetItems(_ ids: Set<String>) -> [PhotoItem] {
        if ids.count == 1, let id = ids.first { return items.first { $0.id == id }.map { [$0] } ?? [] }
        return items.filter { ids.contains($0.id) }
    }

    /// Moves the loupe from its photo to the one `services.culling.advance`
    /// picks in `order` (rebuilt by the edit only when it can reorder); with
    /// none, or one no longer shown, back to the grid. Does nothing in the grid.
    private mutating func advanceLoupe(before beforeOrder: [String]) {
        guard mode == .loupe, let id = focusedItemID else { return }
        if let next = services.culling.advance(from: id, before: beforeOrder, after: order), order.contains(next) {
            focusedItemID = next
        } else {
            mode = .grid
            focusedItemID = nil
        }
    }

    /// The change a single key makes: 0–5, P, X, U; nil for other keys.
    public static func cullChange(for key: LibraryKey) -> CullChange? {
        switch key {
        case .rating(let stars): .rating(stars)
        case .pick: .flag(.pick)
        case .reject: .flag(.reject)
        case .unflag: .flag(.none)
        case .crop, .grid, .confirm, .first, .last: nil
        }
    }

    public mutating func setAutoAdvance(_ on: Bool) {
        autoAdvance = on
    }

    public mutating func dismissCullError() {
        cullError = nil
    }
}

extension CullChange {
    /// A rating or a flag moves the loupe on under Auto Advance; a label never does.
    var advancesLoupe: Bool {
        switch self {
        case .rating, .flag: true
        case .label: false
        }
    }
}
