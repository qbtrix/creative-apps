// UniqueFileNames.swift: the one rule for a file name that is not already in
// a folder ("Card.png", then "Card 2.png", "Card 3.png", …). It lives in
// SuiteModel because Design's export and Library's export both need it
// (docs/factory/lead.md, contract rule 20: one copy of a concept). Stdlib
// only, Linux-safe, Sendable; names compare lowercased, the APFS default.

/// One rule for a file name that is not already in a folder, shared by every app's export.
public enum UniqueFileNames {
    /// "Card.png"; when taken, "Card 2.png", "Card 3.png", … Comparison ignores case (APFS
    /// default); `/` and `:` in `base` become "-"; an empty base is "Untitled".
    ///
    /// The first suffix is 2, never 1. An empty `ext` gives the name with no dot.
    public static func name(_ base: String, extension ext: String, among existing: Set<String>) -> String {
        let stem = Self.stem(base)
        let suffix = ext.isEmpty ? "" : "." + ext
        let taken = Set(existing.map(Self.key))
        let first = stem + suffix
        guard taken.contains(Self.key(first)) else { return first }
        var number = 2
        while taken.contains(Self.key("\(stem) \(number)\(suffix)")) { number += 1 }
        return "\(stem) \(number)\(suffix)"
    }

    /// `base` with every `/` and `:` (the path separators) made "-"; "Untitled"
    /// when it is empty or only whitespace.
    private static func stem(_ base: String) -> String {
        guard !base.allSatisfy(\.isWhitespace) else { return "Untitled" }
        return String(base.map { $0 == "/" || $0 == ":" ? "-" : $0 })
    }

    /// How two names compare: the file system ignores case, so this does too.
    private static func key(_ name: String) -> String {
        name.lowercased()
    }
}
