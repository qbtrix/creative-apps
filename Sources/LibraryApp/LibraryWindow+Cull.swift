// LibraryWindow+Cull.swift: the cull area. The single keys 0–5, P, X and U
// cull the loupe's photo or the selection (`LibraryCatalog.cull`, Auto
// Advance moving the loupe on); Set Rating, Set Flag and Set Label in the
// Metadata menu and the inspector are enabled while there is something to
// cull (`cullHelp` nil); Metadata > Auto Advance is a checkmark that follows
// the model; a refused change's notice closes through `dismissCullError`.
import LibraryModel
import SwiftUI

/// The cull area keeps no window state; the catalog holds it.
final class CullAreaState {}

extension LibraryWindow {
    var cullMenu: LibraryMenu.Cull {
        let canCull = model.cullHelp == nil
        return LibraryMenu.Cull(
            key: { key in
                if let change = LibraryCatalog.cullChange(for: key), model.cullHelp == nil { model.cull(change) }
            },
            setRating: enabled(canCull) { (stars: Int) in model.setRating(stars) },
            setFlag: enabled(canCull) { (flag: PhotoFlag) in model.setFlag(flag) },
            setLabel: enabled(canCull) { (label: PhotoLabel?) in model.setLabel(label) },
            toggleAutoAdvance: { model.setAutoAdvance(!model.autoAdvance) },
            autoAdvance: model.autoAdvance,
            dismissCullError: { model.dismissCullError() })
    }
}
