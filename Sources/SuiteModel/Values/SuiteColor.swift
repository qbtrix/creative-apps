// SuiteColor.swift: a colour as the suite stores it, in its own space and
// never converted on save. Foundation free, Linux-safe, Sendable.

/// The colour spaces a stored colour can be in.
public enum SuiteColorSpace: String, Codable, Sendable { case sRGB, displayP3 }

/// A colour as stored: components 0...1 in their own space, never converted on save.
public struct SuiteColorValue: Codable, Hashable, Sendable {
    public var space: SuiteColorSpace
    public var red: Double, green: Double, blue: Double, alpha: Double
    public init(space: SuiteColorSpace, red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.space = space; self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    /// "RRGGBB" (alpha dropped), for hex rows; components clamped to 0...1.
    public var hex: String {
        func byte(_ v: Double) -> String {
            let n = Int((min(max(v, 0), 1) * 255).rounded())
            let s = String(n, radix: 16, uppercase: true)
            return s.count == 1 ? "0" + s : s
        }
        return byte(red) + byte(green) + byte(blue)
    }
}
