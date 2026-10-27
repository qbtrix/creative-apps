// HexColorEditing.swift: UC2 (SJ12), parsing and formatting the hex field of a
// color row, and FakeHexColorEditing, which accepts six digits only on purpose
// (no #RGB shorthand) and reads and writes those through HexColorText, so it
// can't disagree with the real field on any text it takes. From blueprint
// section 5.2.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct RGB8: Hashable, Sendable {
    public var red: UInt8, green: UInt8, blue: UInt8
    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) { self.red = red; self.green = green; self.blue = blue }
}

public protocol HexColorEditing: Sendable {
    /// "#RRGGBB", "RRGGBB" or "#RGB" in either case; nil otherwise.
    func parse(_ text: String) -> RGB8?
    /// The color after the hex field closes: the parsed color, or `old` for text that isn't one.
    func committed(_ text: String, old: RGB8) -> RGB8
    /// Always "#RRGGBB", upper case.
    func format(_ color: RGB8) -> String
}

/// Accepts six hex digits only (no "#RGB" shorthand).
public struct FakeHexColorEditing: HexColorEditing {
    public init() {}
    public func parse(_ text: String) -> RGB8? {
        let digits = text.hasPrefix("#") ? text.dropFirst() : Substring(text)
        guard digits.count == 6 else { return nil }
        return HexColorText().parse(text)
    }
    public func committed(_ text: String, old: RGB8) -> RGB8 { parse(text) ?? old }
    public func format(_ c: RGB8) -> String { HexColorText().format(c) }
}
