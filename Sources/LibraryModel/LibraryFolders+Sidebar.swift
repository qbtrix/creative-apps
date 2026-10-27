// LibraryFolders+Sidebar.swift (folders FO-6): the FOLDERS rows' click and context menu, on the catalog. A row's
// click runs view.show-folder's body on its folder (with its subfolders' photos, unless that folder is shown
// without them already) and selects the row; Include Subfolders shows the row's folder with them turned the other
// way; any other row's click drops the folder rule and selects that collection. An id no folder has does nothing.
// A click builds the tree once (`folderPath`): the path it finds is applied without a second lookup. Linux-safe.
extension LibraryCatalog {
    /// The folder of FOLDERS row `id`, or nil when no folder in the tree has that id.
    public func folderPath(forRow id: String) -> String? {
        guard LibraryFolders.isRowID(id) else { return nil }
        func find(_ nodes: [FolderNode]) -> String? {
            for node in nodes {
                if LibraryFolders.rowID(for: node.path) == id { return node.path }
                if let hit = find(node.children) { return hit }
            }
            return nil
        }
        return find(folderTree)
    }

    /// The FOLDERS row whose folder the grid shows, nil while no folder rule is on.
    public var selectedFolderRowID: String? { activeFilter.folder.map { LibraryFolders.rowID(for: $0.path) } }

    /// The sidebar's selected row: the shown folder's, else the selected collection's.
    public var sidebarSelection: String { selectedFolderRowID ?? selectedCollectionID }

    /// Whether row `id`'s folder shows its subfolders' photos: true unless it is shown without them.
    public func folderIncludesSubfolders(row id: String) -> Bool {
        guard let scope = activeFilter.folder, LibraryFolders.rowID(for: scope.path) == id else { return true }
        return scope.subfolders
    }

    /// A sidebar row's click: a FOLDERS row shows its folder, any other row is a collection.
    public mutating func selectSidebarRow(_ id: String) {
        if LibraryFolders.isRowID(id) {
            guard let path = folderPath(forRow: id) else { return }
            applyFolder(path, subfolders: folderIncludesSubfolders(row: id))
            return
        }
        if activeFilter.folder != nil, collections.contains(where: { $0.id == id }) {
            var next = activeFilter
            next.folder = nil
            setFilter(next)
        }
        selectCollection(id)
    }

    /// Include Subfolders on row `id`: shows its folder with its subfolders' photos turned the other way.
    public mutating func toggleFolderSubfolders(row id: String) {
        guard let path = folderPath(forRow: id) else { return }
        applyFolder(path, subfolders: !folderIncludesSubfolders(row: id))
    }
}
