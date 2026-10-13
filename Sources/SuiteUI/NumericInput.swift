// NumericInput.swift: turns the text typed into an inspector number field into
// a value, and a value back into that text. Plain Swift with no SwiftUI, so the
// rules are unit-tested on their own. Invariants: parse never returns a value
// outside its range (unless it keeps the old one), never returns NaN, and keeps
// the old value for text that isn't a number; format writes text parse reads,
// rounded to the field's decimals (whole for percent and degrees, one for
// pixels and EV, two by default), halves away from zero. `text` is what a row
// shows (fixed decimals and the unit, "45°", "0.0 pt") and `spoken` what
// VoiceOver reads ("45 degrees"). `committed` keeps the value when the
// typed text is still the text the field opened with.
public enum NumericInput {
    /// The value `text` names, clamped to `range`. Text that isn't a number,
    /// and NaN, give back `old`. Surrounding whitespace is ignored.
    public static func parse(_ text: String, in range: ClosedRange<Double>, keeping old: Double) -> Double {
        let trimmed = String(text.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard let value = Double(trimmed), !value.isNaN else { return old }
        return clamp(value, to: range)
    }

    /// What a typing field commits when it closes on `text`, having opened on
    /// `format(old)`: `old` itself while the text is still that, so a click
    /// and click away never rounds a value the field only showed rounded;
    /// otherwise `parse`.
    public static func committed(_ text: String, in range: ClosedRange<Double>, keeping old: Double) -> Double {
        let trimmed = String(text.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        return trimmed == format(old) ? old : parse(text, in: range, keeping: old)
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

    /// `value` at exactly `decimals` places with its unit: symbols attach
    /// ("45°", "100%", "1.00×"), words take a space ("0.0 pt", "1.5 EV").
    public static func text(_ value: Double, decimals: Int = 2, unit: String = "") -> String {
        let places = min(max(decimals, 0), 6)
        var number = format(value, decimals: places)
        if places > 0, value.isFinite, !number.contains("e") {
            let fraction = number.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first ?? ""
            number += (fraction.isEmpty ? "." : "") + String(repeating: "0", count: max(places - fraction.count, 0))
        }
        guard let first = unit.first else { return number }
        return first.isLetter ? "\(number) \(unit)" : number + unit
    }

    /// `value` as VoiceOver reads it, the unit's symbol spelled out: "45 degrees", "1 pixel".
    public static func spoken(_ value: Double, decimals: Int = 2, unit: String = "") -> String {
        let number = format(value, decimals: decimals)
        let names = ["°": ("degree", "degrees"), "%": ("percent", "percent"), "×": ("times", "times"),
                     "px": ("pixel", "pixels"), "pt": ("point", "points")]
        guard !unit.isEmpty else { return number }
        let name = names[unit].map { number == "1" ? $0.0 : $0.1 } ?? unit
        return "\(number) \(name)"
    }
}
