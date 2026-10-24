// SuiteColor.swift: a colour as the suite stores it, in its own space and
// never converted on save. Foundation free, Linux-safe, Sendable. It stays
// its own type, not the kernel's FillColor: it carries a colour space and is
// the hand-off and pasteboard format. Its `hex` mirrors SuiteKernel's HexText
// (SuiteModel links no other module); SuiteColorHexParityTests pins the two.

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
    public var hex: String {
        func byte(_ v: Double) -> String {
            let n = v.isFinite ? Int((min(max(v, 0), 1) * 255).rounded()) : 0
            let s = String(n, radix: 16, uppercase: true)
            return s.count == 1 ? "0" + s : s
        }
        return byte(red) + byte(green) + byte(blue)
    }
}
