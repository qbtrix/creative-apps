// LibraryCulling.swift: rating, flagging and labelling photos from the keys,
// the menu and the inspector. A change goes to the loupe's photo in the
// loupe, else to the selection, through `services.culling`, and is one undo
// step named for the change. A refused change sets `cullError` and leaves no
// trace. Auto Advance (moving the loupe on) is CU-3. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension LibraryCatalog {
    /// The loupe photo in the loupe, else the selection; empty: nothing to cull.
    public var cullTargets: Set<String> {
        if mode == .loupe { return loupeItem.map { [$0.id] } ?? [] }
        return selection
    }

    /// "Select a photo to rate it." with no targets, else nil.
    public var cullHelp: String? {
        cullTargets.isEmpty ? "Select a photo to rate it." : nil
    }

    /// Applies `change` to `cullTargets` through `services.culling` as one
    /// undo step named `change.undoName`. A throw sets `cullError` and
    /// changes nothing; success clears it. No targets: does nothing.
    public mutating func cull(_ change: CullChange, advance: Bool = true) {
        let ids = cullTargets
        guard !ids.isEmpty else { return }
        let next: [PhotoItem]
        do {
            next = try services.culling.apply(change, to: ids, in: items)
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
        _ = advance  // CU-3 moves the loupe on here when Auto Advance is on.
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
