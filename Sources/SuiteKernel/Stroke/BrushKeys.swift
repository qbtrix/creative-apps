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
    public static func step(size: Double, up: Bool) -> Double { size }

    /// The next hardness for Shift-`]` (up) or Shift-`[`: ±25, clamped 0...100.
    public static func hardnessStep(_ h: Double, up: Bool) -> Double { h }

    /// The action for a key; nil when the key isn't one of these.
    public static func action(for key: Character, shift: Bool, settings: BrushSettings, brushActive: Bool,
                              digits: inout OpacityDigits, now: Double) -> BrushKeyAction? { nil }
}

/// The digit buffer: a digit sets tens, and a second digit within `window` of one that started a pair makes an
/// exact percent.
public struct OpacityDigits: Sendable {
    /// How long, in seconds, a first digit waits for its second.
    public static let window: Double = 0.6

    /// An empty buffer.
    public init() {}

    /// The percent after typing `digit` at `now` (seconds): 1 → 10, 0 → 100, 4 then 5 → 45.
    public mutating func type(_ digit: Int, at now: Double) -> Double { 100 }
}
