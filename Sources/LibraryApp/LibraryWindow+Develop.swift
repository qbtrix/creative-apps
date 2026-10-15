// LibraryWindow+Develop.swift: the develop area, a stub until the develop
// feature fills it: the develop half of the Photo menu (Copy Settings,
// Paste Settings, Reset Develop). The window merges it with the crop half.
import LibraryModel
import SwiftUI

final class DevelopAreaState {}

extension LibraryWindow {
    var developMenu: LibraryMenu.Photo { LibraryMenu.Photo() }
}
