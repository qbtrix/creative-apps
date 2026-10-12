// DesignSidebarItems.swift: sidebar items for Design's pages and Layers rows,
// keyed by page or node id for DesignWorkspace.selectItem. Nesting and the eye
// and lock toggles reach the sidebar with SuiteUI's nested rows (#4).
import DesignModel
import SuiteUI

extension SidebarItem {
    init(page: DesignPage) {
        self.init(id: page.id, title: page.name, systemImage: "doc")
    }

    init(row: DesignRow) {
        self.init(id: row.id, title: row.node.name, systemImage: row.node.kind.systemImage)
    }
}
