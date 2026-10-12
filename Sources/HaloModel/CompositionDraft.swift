// CompositionDraft.swift: the New Composition sheet's draft as the text the
// person typed. The sheet's numeric fields bind to these strings, so every
// keystroke is in the draft and Create never sees a value from before the last
// edit. `settings` parses the text; a field that isn't a number becomes an
// out-of-range value, so CompositionSettings' rules say why it is invalid.
// Linux-safe: no UI imports.

/// The New Composition sheet's draft, with width, height and duration as text.
public struct CompositionDraft: Sendable, Hashable {
    public var name: String
    public var widthText: String
    public var heightText: String
    public var framesPerSecond: Int
    public var durationText: String

    public init(_ settings: CompositionSettings) {
        name = settings.name
        widthText = String(settings.width)
        heightText = String(settings.height)
        framesPerSecond = settings.framesPerSecond
        durationText = Self.text(settings.durationSeconds)
    }

    /// The settings the text describes. A width or height that isn't a whole
    /// number reads as 0 and a duration that isn't a number as 0 seconds, both
    /// outside the valid range.
    public var settings: CompositionSettings {
        CompositionSettings(
            name: name, width: Int(widthText.trimmed) ?? 0, height: Int(heightText.trimmed) ?? 0,
            framesPerSecond: framesPerSecond, durationSeconds: Double(durationText.trimmed) ?? 0)
    }

    /// Why Create can't make a composition from the draft; empty when it can.
    public var problems: [String] { settings.problems }

    /// Whether Create can make a composition from the draft.
    public var isValid: Bool { settings.isValid }

    /// Seconds as text, without a trailing ".0" for whole seconds.
    static func text(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds.rounded() == seconds, abs(seconds) < 1e15 else { return String(seconds) }
        return String(Int(seconds))
    }
}
