// LibraryWindow+Loupe.swift: the loupe area (View menu), kept as today until
// the loupe-viewport feature fills it: Grid, Loupe, Sort By, and Larger and
// Smaller Thumbnails as Zoom In and Zoom Out in the grid.
import LibraryModel
import SwiftUI

final class LoupeAreaState {}

extension LibraryWindow {
    var viewMenu: LibraryMenu.Viewing {
        let inGrid = model.mode == .grid
        return LibraryMenu.Viewing(
            grid: enabled(model.mode == .loupe) { model.showGrid() },
            loupe: enabled(inGrid && !model.isSelectedCollectionEmpty) { model.showLoupe() },
            zoomIn: enabled(inGrid && model.canShowLargerThumbnails) { model.stepCellSize(by: 1) },
            zoomOut: enabled(inGrid && model.canShowSmallerThumbnails) { model.stepCellSize(by: -1) },
            setSort: { model.setSort($0) }, sort: model.sort,
            zoomInTitle: inGrid ? "Larger Thumbnails" : "Zoom In",
            zoomOutTitle: inGrid ? "Smaller Thumbnails" : "Zoom Out")
    }

    /// Called when `model.focusedItemID` changes (the loupe's photo).
    func loupeAreaFocusChanged() {}
}
