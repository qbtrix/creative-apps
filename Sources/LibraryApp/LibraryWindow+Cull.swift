// LibraryWindow+Cull.swift: the cull area. The single keys 0–5, P, X and U
// cull the loupe's photo or the selection (`LibraryAction.cull`, Auto
// Advance moving the loupe on); Set Rating, Set Flag and Set Label in the
// Metadata menu and the inspector are enabled while there is something to
// cull (`cullHelp` nil); Metadata > Auto Advance is a checkmark that follows
// the model; a refused change's notice closes through `dismissCullError`.
// Each runs through the catalog's `run`, which refuses what `help` names.
import LibraryModel
import SwiftUI

/// The cull area keeps no window state; the catalog holds it.
final class CullAreaState {}

extension LibraryWindow {
    var cullMenu: LibraryMenu.Cull {
        let canCull = model.cullHelp == nil
        return LibraryMenu.Cull(
            key: { key in
                if let change = LibraryCatalog.cullChange(for: key) { try? model.run(.cull(change)) }
            },
            setRating: enabled(canCull) { (stars: Int) in try? model.run(.setRating(stars)) },
            setFlag: enabled(canCull) { (flag: PhotoFlag) in try? model.run(.setFlag(flag)) },
            setLabel: enabled(canCull) { (label: PhotoLabel?) in try? model.run(.setLabel(label)) },
            toggleAutoAdvance: { try? model.run(.toggleAutoAdvance) },
            autoAdvance: model.autoAdvance,
            dismissCullError: { try? model.run(.dismissCullError) })
    }
}
