// CompositionSettings.swift: what the New Composition sheet asks for (name,
// size, frame rate, duration in seconds) and the rules that make it valid.
// Linux-safe: no UI imports. The sheet edits a copy as a draft; HaloProject
// only ever builds a composition from settings that pass `isValid`.

/// The settings a new composition is made from.
public struct CompositionSettings: Sendable, Hashable {
    /// The frame rates a composition can play at.
    public static let frameRates = [24, 25, 30, 60]
    /// The width and height a composition can have, in pixels.
    public static let sizeRange = 1...8192
    /// The longest composition, 24 hours; keeps the frame count far from Int.max.
    public static let maxDurationSeconds = 86_400.0

    public var name: String
    public var width: Int
    public var height: Int
    public var framesPerSecond: Int
    public var durationSeconds: Double

    public init(name: String, width: Int = 1920, height: Int = 1080, framesPerSecond: Int = 30, durationSeconds: Double = 10) {
        self.name = name
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.durationSeconds = durationSeconds
    }

    /// Why the settings can't make a composition, one line per problem, in
    /// form order; empty when they can.
    public var problems: [String] {
        var problems: [String] = []
        if name.trimmed.isEmpty { problems.append("Enter a name.") }
        let sizes = "\(Self.sizeRange.lowerBound) to \(Self.sizeRange.upperBound)"
        if !Self.sizeRange.contains(width) { problems.append("Width must be \(sizes) pixels.") }
        if !Self.sizeRange.contains(height) { problems.append("Height must be \(sizes) pixels.") }
        if !Self.frameRates.contains(framesPerSecond) { problems.append("Frame rate must be 24, 25, 30 or 60 fps.") }
        if !(durationSeconds > 0 && durationSeconds <= Self.maxDurationSeconds) {
            problems.append("Duration must be more than 0 seconds and at most 24 hours.")
        }
        return problems
    }

    /// Whether Create can make a composition from these settings.
    public var isValid: Bool { problems.isEmpty }

    /// The duration in whole frames, at least 1; nil while invalid.
    public var durationFrames: Int? {
        guard isValid else { return nil }
        return max(1, Int((durationSeconds * Double(framesPerSecond)).rounded()))
    }
}

extension String {
    /// The string without leading and trailing whitespace.
    var trimmed: String { String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed()) }

    /// The string as names compare: trimmed and lowercased. String equality
    /// is already Unicode-canonical, so composed and decomposed forms match.
    var nameKey: String { trimmed.lowercased() }
}
