// LibraryWindow+Cull.swift: the cull area, a stub until the cull feature
// fills it. Set Rating, Set Flag and Set Label call the catalog's methods so
// the inspector and the Metadata menu keep working while photos are selected
// (nil, so disabled with the reason, while none are); the single keys, Auto
// Advance and the cull error wait for that feature.
import LibraryModel
import SwiftUI

final class CullAreaState {}

extension LibraryWindow {
    var cullMenu: LibraryMenu.Cull {
        let canEdit = !model.selection.isEmpty
        return LibraryMenu.Cull(
            key: nil,
            setRating: enabled(canEdit) { (stars: Int) in model.setRating(stars) },
            setFlag: enabled(canEdit) { (flag: PhotoFlag) in model.setFlag(flag) },
            setLabel: enabled(canEdit) { (label: PhotoLabel?) in model.setLabel(label) })
    }
}
