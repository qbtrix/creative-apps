// PhotoCommands+Filter.swift (adjust-everywhere AJ-3, AJ-9): Photo's Filter
// menu and Image > Adjustments from FilterMenu, each item its catalog command on
// the focused window's workspace, so it is off with the command's reason. An
// item sends `.filter(.open(item))`: a sheet's item opens its FilterSheet,
// Invert runs at once (PhotoWindow+Filter.swift).
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI

extension PhotoCommands {
    var filterMenu: some Commands { CommandMenu("Filter") { PhotoFilterMenu(menu: menu) } }
}

/// One FilterMenu item as a menu item from its catalog spec.
struct PhotoFilterItem: View {
    let item: FilterMenuItem
    let menu: PhotoMenu

    var body: some View {
        if let spec = PhotoWorkspace.catalog.spec(item.command) {
            MenuCommand(spec, on: menu.workspace, title: item.title) { menu.perform(.filter(.open(item))) }
        }
    }
}

/// The Filter menu's items, a titled group as its submenu.
struct PhotoFilterMenu: View {
    let menu: PhotoMenu

    var body: some View {
        ForEach(FilterMenu.filter, id: \.self) { group in
            if let title = group.title {
                Menu(title) { ForEach(group.items, id: \.self) { PhotoFilterItem(item: $0, menu: menu) } }
            } else {
                ForEach(group.items, id: \.self) { PhotoFilterItem(item: $0, menu: menu) }
            }
        }
    }
}

/// Image > Adjustments.
struct PhotoAdjustmentsMenu: View {
    let menu: PhotoMenu

    var body: some View {
        Menu("Adjustments") {
            ForEach(FilterMenu.adjustments, id: \.self) { PhotoFilterItem(item: $0, menu: menu) }
        }
    }
}
