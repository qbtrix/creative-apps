// PhotoTextBoxKeys.swift (#4798, #5951): keys the canvas gets while a Type tool box is open go into the box.
// The field over the canvas takes the typing when it holds focus; when the canvas keeps it, its letters used to
// pick tools (S, U, M ...), the first such pick committed the still-empty box, and Return ran the canvas's
// confirm, so no text layer came. Now a printable key adds to the draft, Delete drops its last character,
// Return commits and Escape cancels, as the field does. Linux-safe.

/// What a key pressed on the canvas does to the open Type tool box.
public enum PhotoTextBoxKey: Hashable, Sendable {
    /// The box's words become these.
    case type(String)
    /// Adds the box's words as a text layer and closes it.
    case commit
    /// Closes the box and drops its words.
    case cancel
}

extension PhotoTextBox {
    /// What `characters`, one key press's text, asks of this box; nil for a key the box doesn't take (an arrow,
    /// a function key, an empty press), which then reaches the canvas as before.
    public func key(_ characters: String) -> PhotoTextBoxKey? {
        switch characters {
        case "\r", "\n", "\r\n", "\u{3}": return .commit
        case "\u{1B}": return .cancel
        case "\u{7F}", "\u{8}": return .type(String(draft.dropLast()))
        default:
            guard !characters.isEmpty, characters.unicodeScalars.allSatisfy(Self.isTyped) else { return nil }
            return .type(draft + characters)
        }
    }

    /// A scalar a key types: not a control character, and not one of the private-use codes the
    /// arrow and function keys carry (U+F700 to U+F8FF).
    private static func isTyped(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x20 && scalar.value != 0x7F && !(0xF700...0xF8FF).contains(scalar.value)
    }
}

extension PhotoWorkspace {
    /// Does what `key` asks of the open box; nothing without one.
    public mutating func pressTextKey(_ key: PhotoTextBoxKey) {
        switch key {
        case .type(let words): typeText(words)
        case .commit: commitTextBox()
        case .cancel: cancelTextBox()
        }
    }
}
