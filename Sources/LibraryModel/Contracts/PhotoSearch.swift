// Contracts/PhotoSearch.swift (metadata-more MD-4 slot, filled by MD-20): the
// window's search field as a value. The text and `isEmpty` are real now;
// `matches` lets every photo through and there are no suggestions until MD-20
// parses tokens, quoted phrases, `field:value` and number comparisons. The
// catalog's stored search (`search`, `setSearch(_:)`) is MD-21's. Linux-safe.

/// What the search field holds, and which photos it lets through.
public struct PhotoSearch: Hashable, Sendable {
    /// The field's text, as typed.
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    /// Nothing but spaces: the search shows every photo.
    public var isEmpty: Bool {
        text.allSatisfy(\.isWhitespace)
    }

    /// Whether `photo` matches every token. MD-20; true until then.
    public func matches(_ photo: PhotoItem) -> Bool { true }
}

extension LibraryCatalog {
    /// Searches for the field's suggestions list (`lens:"50mm F1.8"`), at
    /// most `limit`. MD-20; [] until then.
    public func searchSuggestions(prefix: String, limit: Int = 8) -> [String] { [] }
}

extension MetadataInspectorID {
    /// The window's search field.
    public static let search = "library.search"
}
