// CompositionDraft.swift: the New Composition sheet's draft as the text the
// person typed. The sheet's numeric fields bind to these strings, so every
// keystroke is in the draft and Create never sees a value from before the last
// edit. `settings` parses the text; a field that isn't a number becomes an
// out-of-range value so Create stays off, and `problems` says the field needs
// a number rather than giving the range.
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
            name: name, width: Self.wholeNumber(widthText) ?? 0, height: Self.wholeNumber(heightText) ?? 0,
            framesPerSecond: framesPerSecond, durationSeconds: Self.seconds(durationText) ?? 0)
    }

    /// Why Create can't make a composition from the draft; empty when it can.
    /// A field whose text isn't a number says so instead of giving the range.
    public var problems: [String] { fieldProblems.map(\.text) }

    /// The problems with the field each is about, in form order.
    public var fieldProblems: [CompositionProblem] {
        settings.fieldProblems.map { problem in
            switch problem.field {
            case .width where Self.wholeNumber(widthText) == nil:
                CompositionProblem(.width, "Width must be a whole number of pixels.")
            case .height where Self.wholeNumber(heightText) == nil:
                CompositionProblem(.height, "Height must be a whole number of pixels.")
            case .duration where Self.seconds(durationText) == nil:
                CompositionProblem(.duration, "Duration must be a number of seconds.")
            default: problem
            }
        }
    }

    /// The problems the sheet shows right under `field`; empty when it's fine.
    public func problems(for field: CompositionField) -> [String] {
        fieldProblems.filter { $0.field == field }.map(\.text)
    }

    /// Whether Create can make a composition from the draft.
    public var isValid: Bool { settings.isValid }

    /// The whole number the text spells, or nil when it isn't one. Surrounding
    /// whitespace is ignored and a fraction of only zeros ("1920.0") is allowed.
    /// Digits too long for Int read as Int.max or Int.min, still out of range.
    static func wholeNumber(_ text: String) -> Int? {
        let text = text.trimmed
        if let number = Int(text) { return number }
        let digits = text.drop { $0 == "+" || $0 == "-" }
        if text.count - digits.count <= 1, !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) {
            return text.hasPrefix("-") ? Int.min : Int.max
        }
        guard let dot = text.firstIndex(of: "."), let number = Int(text[..<dot]),
            text[text.index(after: dot)...].allSatisfy({ $0 == "0" })
        else { return nil }
        return number
    }

    /// The seconds the text spells, or nil when it isn't a number.
    static func seconds(_ text: String) -> Double? { Double(text.trimmed) }

    /// Seconds as text, without a trailing ".0" for whole seconds.
    static func text(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds.rounded() == seconds, abs(seconds) < 1e15 else { return String(seconds) }
        return String(Int(seconds))
    }
}
