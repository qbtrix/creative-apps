// NameKey.swift: the key composition names compare by, so renaming refuses a
// look-alike of a taken name and New Composition and Duplicate number one.
// Linux-safe: case folding lives in full Foundation, not FoundationEssentials,
// so this file imports Foundation (swift-corelibs-foundation on Linux).
import Foundation

extension String {
    /// The string as names compare: trimmed and case folded, so STRASSE and
    /// straße match where lowercasing alone would not. String equality is
    /// already Unicode-canonical, so composed and decomposed forms match.
    var nameKey: String { trimmed.folding(options: .caseInsensitive, locale: nil) }
}
