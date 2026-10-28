// PhotoCommands+Filter.swift (adjust-everywhere AJ-3): Photo's Filter menu and
// Image > Adjustments from FilterMenu, each item its catalog command. Until
// AJ-8/AJ-9 every item sits on PendingAdjustTarget: off, "Filters arrive with AJ-5."
import SuiteImaging
import SuiteUI
import SwiftUI

extension PhotoCommands {
    var filterMenu: some Commands { CommandMenu("Filter") { PhotoFilterMenu() } }
}

/// One FilterMenu item as a menu item from its catalog spec.
struct PhotoFilterItem: View {
    let item: FilterMenuItem
    private let target = PendingAdjustTarget()

    var body: some View {
        if let spec = AdjustCommands.specs(PendingAdjustTarget.self).first(where: { $0.id == item.command }) {
            // Off on the pending target, so it never runs; AJ-9 opens the sheet here.
            MenuCommand(spec, on: target, title: item.title) {}
        }
    }
}

/// The Filter menu's items, a titled group as its submenu.
struct PhotoFilterMenu: View {
    var body: some View {
        ForEach(FilterMenu.filter, id: \.self) { group in
            if let title = group.title {
                Menu(title) { ForEach(group.items, id: \.self) { PhotoFilterItem(item: $0) } }
            } else {
                ForEach(group.items, id: \.self) { PhotoFilterItem(item: $0) }
            }
        }
    }
}

/// Image > Adjustments.
struct PhotoAdjustmentsMenu: View {
    var body: some View {
        Menu("Adjustments") {
            ForEach(FilterMenu.adjustments, id: \.self) { PhotoFilterItem(item: $0) }
        }
    }
}
