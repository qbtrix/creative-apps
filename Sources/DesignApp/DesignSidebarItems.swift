// DesignSidebarItems.swift: sidebar items for Design's pages and Layers rows,
// keyed by page or node id for DesignWorkspace.selectItem. A row with children
// carries an expand toggle that DesignWindow routes to toggleExpanded; it
// stands in for a disclosure until SuiteUI's sidebar takes a controlled
// expanded set (#111). Eye and lock toggles come with #45.
import DesignModel
import SuiteUI

extension SidebarItem {
    /// The id of a Layers row's expand toggle.
    static let designExpand = "expand"

    init(page: DesignPage) {
        self.init(id: page.id, title: page.name, systemImage: "doc")
    }

    init(row: DesignRow, isExpanded: Bool = false) {
        var toggles: [SidebarToggle] = []
        if !row.node.children.isEmpty {
            toggles.append(
                SidebarToggle(
                    id: Self.designExpand, title: isExpanded ? "Collapse" : "Expand",
                    onSymbol: "chevron.down", offSymbol: "chevron.right", isOn: isExpanded))
        }
        self.init(id: row.id, title: row.node.name, systemImage: row.node.kind.systemImage, toggles: toggles)
    }
}
