// LibraryWindow+Crop.swift: the crop area, a stub until the crop feature
// fills it: the crop half of the Photo menu (Crop, Reset Crop) and R and
// Return in the loupe. The window merges it with the develop half.
import LibraryModel
import SwiftUI

final class CropAreaState {}

extension LibraryWindow {
    var cropMenu: LibraryMenu.Photo { LibraryMenu.Photo() }
}
