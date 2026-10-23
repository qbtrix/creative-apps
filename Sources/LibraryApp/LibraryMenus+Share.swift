// LibraryMenus+Share.swift: the share area's LibraryMenu sub-struct (share-sheet
// SH-4, live since SH-5). LibraryShareItems.swift fills it from the catalog's `shareHelp`.
extension LibraryMenu {
    /// File > Share… (share).
    struct Share {
        var share: Action?
        var help: String?  // why Share… can't act
    }
}
