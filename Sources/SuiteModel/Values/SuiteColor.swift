// SuiteColor.swift: a colour as the suite stores it, in its own space and
// never converted on save. Foundation free, Linux-safe, Sendable. It stays
// its own type, not the kernel's FillColor: it carries a colour space and is
// the hand-off and pasteboard format. Its `hex` is SuiteKernel's HexText over
// the components as they are (no space conversion), without the "#".
import SuiteKernel


/// The colour spaces a stored colour can be in.
public enum SuiteColorSpace: String, Codable, Sendable { case sRGB, displayP3 }

/// A colour as stored: components 0...1 in their own space, never converted on save.
public struct SuiteColorValue: Codable, Hashable, Sendable {
    public var space: SuiteColorSpace
    public var red: Double, green: Double, blue: Double, alpha: Double
    public init(space: SuiteColorSpace, red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.space = space; self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    /// "RRGGBB" (alpha dropped), for hex rows: HexText's format without the "#", components clamped to 0...1,
    /// a NaN or an infinity reads 00.
    public var hex: String { String(HexText.format(FillColor(r: red, g: green, b: blue)).dropFirst()) }
}
