// NumericInput.swift: turns the text typed into an inspector number field into
// a value, and a value back into that text. Plain Swift with no SwiftUI, so the
// rules are unit-tested on their own. Invariants: parse never returns a value
// outside its range (unless it keeps the old one), never returns NaN, and keeps
// the old value for text that isn't a number; format writes text parse reads.
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

    /// `value` rounded to two decimals, without trailing zeros ("12", "0.5").
    /// Locale-free, so `parse` reads it back.
    public static func format(_ value: Double) -> String {
        // Past 1e15 every Double is whole, and Int64 and the * 100 could overflow.
        guard value.isFinite, abs(value) < 1e15 else { return String(value) }
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int64(rounded)) : String(rounded)
    }
}
