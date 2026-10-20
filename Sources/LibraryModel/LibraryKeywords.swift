// LibraryKeywords.swift (metadata-more MD-4 slot, filled by MD-10): keywords
// on the cull targets. `keywordHelp` and the Info tab's identifiers are real
// now; the edits change nothing and record no undo step, and the states and
// suggestions are empty, until MD-10 builds them (normalize, one named step
// per gesture, partial states, ranked suggestions). Linux-safe.

/// One keyword across the cull targets: on `count` of `total` photos.
public struct KeywordState: Hashable, Sendable {
    public let name: String
    public let count: Int
    public let total: Int

    public init(name: String, count: Int, total: Int) {
        self.name = name
        self.count = count
        self.total = total
    }

    /// On some targets but not all ("Beach 3 of 5"), drawn dimmer.
    public var isPartial: Bool { count < total }
}

extension LibraryCatalog {
    /// "Select a photo to add keywords." with no cull targets, else nil.
    public var keywordHelp: String? {
        cullTargets.isEmpty ? "Select a photo to add keywords." : nil
    }

    /// Each keyword on any cull target with how many have it. MD-10; [] until then.
    public var keywordStates: [KeywordState] { [] }

    /// Adds the comma-separated keywords in `text` to the cull targets as one
    /// "Add Keyword" or "Add Keywords" step. MD-10; changes nothing until then.
    public mutating func addKeywords(_ text: String) {}

    /// Makes a partial keyword whole: adds `name` to every cull target as one
    /// "Add Keyword" step. MD-10; changes nothing until then.
    public mutating func addKeyword(toAll name: String) {}

    /// Removes `name` (any case) from the cull targets as one "Remove Keyword"
    /// step. MD-10; changes nothing until then.
    public mutating func removeKeyword(_ name: String) {}

    /// The catalog's keywords for the add field, ranked, at most `limit`.
    /// MD-10; [] until then.
    public func keywordSuggestions(prefix: String, limit: Int = 8) -> [String] { [] }
}

extension MetadataInspectorID {
    /// The Keywords row's add field.
    public static let keywordsField = "library.metadata.keywords"
    /// The Title field.
    public static let title = "library.metadata.title"
    /// The Caption field.
    public static let caption = "library.metadata.caption"
    /// The Sidecar row's text.
    public static let sidecar = "library.metadata.sidecar"

    /// The token for keyword `name`; the same whatever its case.
    public static func keyword(_ name: String) -> String {
        "library.metadata.keyword.\(name.lowercased())"
    }

    /// The remove button on keyword `name`'s token.
    public static func removeKeyword(_ name: String) -> String {
        "library.metadata.removeKeyword.\(name.lowercased())"
    }
}
