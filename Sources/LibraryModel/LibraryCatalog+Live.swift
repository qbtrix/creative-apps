// LibraryCatalog+Live.swift (editor-menus EM-7): the window takes back the catalog a live command ran on. The live
// channel reads the window's catalog as `LibraryHeadless(catalog:)`, runs the command there, and lands the result
// here. Linux-safe.

extension LibraryCatalog {
    /// Becomes the catalog `ran` holds: this one with a live command applied.
    public mutating func takeLive(_ ran: LibraryHeadless) {
        self = ran.library
    }
}
