// LibraryMenus+Share.swift: the share area's LibraryMenu sub-struct (share-sheet
// SH-4). LibraryShareItems.swift fills it from the catalog's `shareHelp`.
extension LibraryMenu {
    /// File > Share… (share).
    struct Share {
        /// What File > Share… says once the selection could share, until SH-5 wires the menu.
        static let menuNotBuilt = "Sharing from the File menu arrives with SH-5."

        var share: Action?
        var help: String?  // why Share… can't act
    }
}
