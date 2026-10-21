// BrushKeys.swift (brush-keys BK-1 stubs, BK-3 bodies): the keys a painter's hands expect. `]` and `[` step the
// brush size in bands that grow with it, Shift-`]` and Shift-`[` move hardness by a quarter, and digits set opacity
// in tens (0 is 100%) or, two typed within `OpacityDigits.window`, an exact percent. With no brush tool the digits
// go to the selected layers. SuiteUI's `ToolKeys` reads the event; this file holds the rule.

/// What a brush key does: an edit of the active brush, or an opacity percent for the selected layers.
public enum BrushKeyAction: Hashable, Sendable {
    /// Size, hardness or opacity on the active brush.
    case brush(BrushEdit)
    /// A percent, on the selected layers.
    case layerOpacity(Double)
}

/// The brush keys' rule: size steps, hardness steps and the key-to-action map.
public enum BrushKeys {
    /// The next size for `]` (up) or `[`: steps of 1 under 10, 5 under 100, 25 under 300, 50 above; clamped to
    /// BrushSettings.ranges.size.
    public static func step(size: Double, up: Bool) -> Double {
        let range = BrushSettings.ranges.size
        guard size.isFinite else { return range.lowerBound }
        // Up takes the band the size is in; down takes the band below at a boundary (10 → 9).
        let step = bands.first { up ? size < $0.below : size <= $0.below }?.step ?? 50
        let next = up ? (size / step).rounded(.down) * step + step : (size / step).rounded(.up) * step - step
        return Swift.min(range.upperBound, Swift.max(range.lowerBound, next))
    }

    /// The size bands: under `below`, a step of `step`; the sizes snap to the band's grid.
    static let bands: [(below: Double, step: Double)] = [(10, 1), (100, 5), (300, 25), (.infinity, 50)]

    /// The next hardness for Shift-`]` (up) or Shift-`[`: ±25, clamped 0...100.
    public static func hardnessStep(_ h: Double, up: Bool) -> Double {
        let range = BrushSettings.ranges.percent
        guard h.isFinite else { return range.upperBound }
        return Swift.min(range.upperBound, Swift.max(range.lowerBound, h + (up ? 25 : -25)))
    }

    /// The action for a key; nil when the key isn't one of these. `[` and `]` (Shift for hardness; `{` and `}`
    /// read as Shift) act only with a brush; a digit sets the brush's opacity, or the layers' with no brush;
    /// Shift-digits do nothing.
    public static func action(for key: Character, shift: Bool, settings: BrushSettings, brushActive: Bool,
                              digits: inout OpacityDigits, now: Double) -> BrushKeyAction? {
        switch key {
        case "[", "]", "{", "}":
            guard brushActive else { return nil }
            let up = key == "]" || key == "}"
            return shift || key == "{" || key == "}"
                ? .brush(.hardness(hardnessStep(settings.hardness, up: up)))
                : .brush(.size(step(size: settings.size, up: up)))
        default:
            guard !shift, let digit = key.wholeNumberValue, (0...9).contains(digit), key.isASCII else { return nil }
            let percent = digits.type(digit, at: now)
            return brushActive ? .brush(.opacity(percent)) : .layerOpacity(percent)
        }
    }
}

/// The digit buffer: a digit sets tens, and a second digit within `window` of one that started a pair makes an
/// exact percent.
public struct OpacityDigits: Sendable {
    /// How long, in seconds, a first digit waits for its second.
    public static let window: Double = 0.6

    /// The digit that started a pair and when it was typed; nil once a pair completes.
    var first: (digit: Int, at: Double)?

    /// An empty buffer.
    public init() {}

    /// The percent after typing `digit` at `now` (seconds): 1 → 10, 0 → 100, 4 then 5 → 45, 0 then 5 → 5.
    /// A digit out of 0...9 is clamped into it.
    public mutating func type(_ digit: Int, at now: Double) -> Double {
        let digit = Swift.min(9, Swift.max(0, digit))
        if let first, now - first.at >= 0, now - first.at < Self.window {
            self.first = nil
            return Double(first.digit * 10 + digit)
        }
        first = (digit, now)
        return digit == 0 ? 100 : Double(digit * 10)
    }
}
