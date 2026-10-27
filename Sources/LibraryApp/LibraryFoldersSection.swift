// LibraryFoldersSection.swift: the sidebar's FOLDERS section (folders FO-3), under Collections. Each folder of
// the catalog's FolderNode tree is a SuiteUI row with its count, its subfolders behind the row's disclosure;
// its id is `library.folder.<path-hash>` (LibraryFolders.rowID). A row's context menu has Show Folder and
// Include Subfolders, both disabled with view.show-folder's reason while it can't run. A row's click shows its
// folder in the grid and Include Subfolders turns its subfolders' photos the other way (FO-6, the catalog's
// selectSidebarRow and toggleFolderSubfolders). A folder whose photos are all missing is dimmed and carries the
// missing badge (the grid's exclamationmark.triangle, as a SidebarNotice). A tree with no folders draws no section.
import LibraryModel
import SuiteUI
import SwiftUI

enum LibraryFoldersSection {
    /// FOLDERS with one row per root, or nil when there are no folders.
    static func section(_ tree: [FolderNode]) -> SidebarSection? {
        tree.isEmpty ? nil : SidebarSection(id: "folders", title: "Folders", items: tree.map(row))
    }

    /// The badge on a folder whose photos are all missing: the grid's missing symbol.
    static let missingNotice = SidebarNotice(systemImage: "exclamationmark.triangle", title: "Every photo in this folder is missing")

    /// A folder's row, dimmed and badged when every photo under it is missing.
    static func row(_ node: FolderNode) -> SidebarItem {
        SidebarItem(
            id: LibraryFolders.rowID(for: node.path), title: node.name, systemImage: "folder", count: node.totalCount,
            children: node.children.map(row), isDimmed: node.allMissing, notice: node.allMissing ? missingNotice : nil)
    }

    /// A folder row's context menu: each item disabled with `help` while view.show-folder can't run.
    static func actions(
        help: String?, show: @escaping @MainActor () -> Void = {},
        toggleSubfolders: @escaping @MainActor () -> Void = {}
    ) -> [ToolbarAction] {
        [
            ToolbarAction("Show Folder", systemImage: "folder", unavailableHelp: help, perform: show),
            ToolbarAction("Include Subfolders", systemImage: "folder.badge.plus", unavailableHelp: help, perform: toggleSubfolders),
        ]
    }
}
