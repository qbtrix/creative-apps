// LibraryFoldersSection.swift: the sidebar's FOLDERS section (folders FO-3), under Collections. Each folder of
// the catalog's FolderNode tree is a SuiteUI row with its count, its subfolders behind the row's disclosure;
// its id is `library.folder.<path-hash>` (LibraryFolders.rowID). A row's context menu has Show Folder and
// Include Subfolders, both disabled with view.show-folder's reason while it can't run ("Folders arrive with
// FO-4." on the stubs), and a row's click runs nothing until then. A tree with no folders draws no section.
// Until FO-4 builds the tree, a test can show `sample` through `stubTree` (DEBUG only). FO-6 runs the click.
import LibraryModel
import SuiteUI
import SwiftUI

enum LibraryFoldersSection {
    #if DEBUG
    /// The tree the window shows instead of the catalog's, for a test while FO-4's stub builds none.
    @MainActor static var stubTree: [FolderNode]?
    #endif

    /// The tree the sidebar shows for `model`.
    @MainActor static func tree(_ model: LibraryCatalog) -> [FolderNode] {
        #if DEBUG
        if let stubTree { return stubTree }
        #endif
        return model.folderTree
    }

    /// FOLDERS with one row per root, or nil when there are no folders.
    static func section(_ tree: [FolderNode]) -> SidebarSection? {
        tree.isEmpty ? nil : SidebarSection(id: "folders", title: "Folders", items: tree.map(row))
    }

    /// A folder's row, dimmed when every photo under it is missing.
    static func row(_ node: FolderNode) -> SidebarItem {
        SidebarItem(
            id: LibraryFolders.rowID(for: node.path), title: node.name, systemImage: "folder", count: node.totalCount,
            children: node.children.map(row), isDimmed: node.allMissing)
    }

    /// A folder row's context menu: each item disabled with `help` while view.show-folder can't run.
    static func actions(help: String?) -> [ToolbarAction] {
        [
            ToolbarAction("Show Folder", systemImage: "folder", unavailableHelp: help, perform: {}),
            ToolbarAction("Include Subfolders", systemImage: "folder.badge.plus", unavailableHelp: help, perform: {}),
        ]
    }

    /// A small tree for tests and snapshots: trips with 2025 and 2026 inside, trip and family.
    static let sample: [FolderNode] = [
        FolderNode(path: "/Photos/trips", name: "trips", ownCount: 1, totalCount: 4, allMissing: false, children: [
            FolderNode(path: "/Photos/trips/2025", name: "2025", ownCount: 2, totalCount: 2, allMissing: false, children: []),
            FolderNode(path: "/Photos/trips/2026", name: "2026", ownCount: 1, totalCount: 1, allMissing: false, children: []),
        ]),
        FolderNode(path: "/Photos/trip", name: "trip", ownCount: 1, totalCount: 1, allMissing: false, children: []),
        FolderNode(path: "/Photos/family", name: "family", ownCount: 2, totalCount: 2, allMissing: true, children: []),
    ]
}
