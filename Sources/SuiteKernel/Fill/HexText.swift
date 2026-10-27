// HexText.swift: the suite's one hex colour codec (#5078), beside FillColor, the colour every app hands across:
// FlareCore's `Color`, sRGB components 0...1 with straight alpha. Every hex field, eyedropper readout, SVG writer
// and New-document background parses and formats through here, so one colour reads the same text in every app.
// Parse takes "#RGB", "#RRGGBB" or "#RRGGBBAA", one leading "#" optional, either case, surrounding whitespace
// ignored; anything else is nil. Format writes upper case "#RRGGBB" (callers that need lower case, like SVG,
// lowercase it), plus the alpha byte only when asked for and not FF. `byte` is the one channel rounding: nearest,
// clamped to 0...255, a NaN or an infinity reads 0. Linux-safe, no Foundation.

public enum HexText {
    /// The colour `text` names, or nil when it isn't a hex colour. Without an alpha byte the colour is opaque.
    public static func parse(_ text: String) -> FillColor? {
        var digits = Substring(text).drop(while: \.isWhitespace)
        while digits.last?.isWhitespace == true { digits.removeLast() }
        if digits.first == "#" { digits.removeFirst() }
        let full = digits.count == 3 ? String(digits.flatMap { [$0, $0] }) : String(digits)
        guard full.count == 6 || full.count == 8, full.allSatisfy(\.isHexDigit),
              let value = UInt32(full, radix: 16) else { return nil }
        let rgba = full.count == 6 ? value << 8 | 0xFF : value
        func channel(_ shift: UInt32) -> Double { Double(rgba >> shift & 0xFF) / 255 }
        return FillColor(r: channel(24), g: channel(16), b: channel(8), a: channel(0))
    }

    /// `color` as "#RRGGBB", upper case; with `alpha`, "#RRGGBBAA" when its alpha byte isn't FF.
    public static func format(_ color: FillColor, alpha: Bool = false) -> String {
        var bytes = [color.r, color.g, color.b].map(byte)
        if alpha, byte(color.a) != 255 { bytes.append(byte(color.a)) }
        return "#" + bytes.map { ($0 < 16 ? "0" : "") + String($0, radix: 16, uppercase: true) }.joined()
    }

    /// A 0...1 channel as 0...255, rounded to nearest; out of range clamps, a NaN or an infinity reads 0.
    public static func byte(_ channel: Double) -> UInt8 {
        channel.isFinite ? UInt8((min(max(channel, 0), 1) * 255).rounded()) : 0
    }
}
