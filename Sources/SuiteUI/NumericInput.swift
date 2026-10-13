// NumericInput.swift: turns the text typed into an inspector number field into
// a value, and a value back into that text. Plain Swift with no SwiftUI, so the
// rules are unit-tested on their own. Invariants: parse never returns a value
// outside its range (unless it keeps the old one), never returns NaN, and keeps
// the old value for text that isn't a number; format writes text parse reads,
// rounded to the field's decimals (whole for percent and degrees, one for
// pixels and EV, two by default), halves away from zero.
public enum NumericInput {
    /// The value `text` names, clamped to `range`. Text that isn't a number,
    /// and NaN, give back `old`. Surrounding whitespace is ignored.
    public static func parse(_ text: String, in range: ClosedRange<Double>, keeping old: Double) -> Double {
        let trimmed = String(text.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard let value = Double(trimmed), !value.isNaN else { return old }
        return clamp(value, to: range)
    }

    /// `value` moved into `range`; NaN gives the range's lower bound.
    public static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        value.isNaN ? range.lowerBound : min(max(value, range.lowerBound), range.upperBound)
    }

    /// `value` rounded to `decimals` places (0 to 6; two by default), without
    /// trailing zeros ("12", "0.5"). Halves round away from zero, so 0.5 at no
    /// decimals reads "1" and -2.5 reads "-3". Locale-free, so `parse` reads it back.
    public static func format(_ value: Double, decimals: Int = 2) -> String {
        // Past 1e15 every Double is whole, and Int64 and the scaling could overflow.
        guard value.isFinite, abs(value) < 1e15 else { return String(value) }
        var scale = 1.0
        for _ in 0..<min(max(decimals, 0), 6) { scale *= 10 }
        let rounded = (value * scale).rounded() / scale
        guard rounded != rounded.rounded() else { return String(Int64(rounded)) }
        return String(rounded)
    }
}
