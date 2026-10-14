// NameKey.swift: the key composition names compare by, so renaming refuses a
// look-alike of a taken name and New Composition and Duplicate number one,
// and the normalized form names are stored in.
// Linux-safe: case folding lives in full Foundation, not FoundationEssentials,
// so this file imports Foundation (swift-corelibs-foundation on Linux).
import Foundation

extension String {
    /// The string as names compare: normalized and case folded, so STRASSE
    /// and straße match where lowercasing alone would not. String equality is
    /// already Unicode-canonical, so composed and decomposed forms match.
    var nameKey: String { normalizedName.folding(options: .caseInsensitive, locale: nil) }

    /// The string as a name is stored: invisible format characters (Unicode
    /// category Cf, such as zero-width spaces and byte order marks) dropped,
    /// every run of whitespace (tabs, no-break and thin spaces, newlines)
    /// collapsed to one space, and the ends trimmed. A zero-width joiner
    /// between two emoji is kept, since it draws them as one.
    var normalizedName: String {
        let scalars = Array(unicodeScalars)
        var out = String.UnicodeScalarView()
        var pendingSpace = false
        for (index, scalar) in scalars.enumerated() {
            let properties = scalar.properties
            if properties.generalCategory == .format {
                guard scalar == "\u{200D}", joinsEmoji(after: out.last, before: scalars.dropFirst(index + 1).first)
                else { continue }
            }
            if properties.isWhitespace {
                pendingSpace = !out.isEmpty
                continue
            }
            if pendingSpace { out.append(" ") }
            pendingSpace = false
            out.append(scalar)
        }
        return String(out)
    }
}

/// Whether a zero-width joiner between `previous` and `next` is part of an
/// emoji sequence: emoji (or an emoji's variation selector or skin tone) on
/// the left, an emoji on the right, neither one plain ASCII.
private func joinsEmoji(after previous: Unicode.Scalar?, before next: Unicode.Scalar?) -> Bool {
    guard let previous, let next else { return false }
    let left = previous == "\u{FE0F}" || previous.properties.isEmojiModifier
        || (previous.properties.isEmoji && !previous.isASCII)
    return left && next.properties.isEmoji && !next.isASCII
}
