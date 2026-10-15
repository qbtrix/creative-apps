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
            setRating: canEdit ? { model.setRating($0) } : nil,
            setFlag: canEdit ? { model.setFlag($0) } : nil,
            setLabel: canEdit ? { model.setLabel($0) } : nil)
    }
}
