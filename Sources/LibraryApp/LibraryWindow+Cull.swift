// LibraryWindow+Cull.swift: the cull area, a stub until the cull feature
// fills it. Set Rating, Set Flag and Set Label call the catalog's methods so
// the inspector and the Metadata menu keep working; the single keys, Auto
// Advance and the cull error wait for that feature.
import LibraryModel
import SwiftUI

final class CullAreaState {}

extension LibraryWindow {
    var cullMenu: LibraryMenu.Cull {
        LibraryMenu.Cull(
            key: nil,
            setRating: { model.setRating($0) }, setFlag: { model.setFlag($0) }, setLabel: { model.setLabel($0) })
    }
}
