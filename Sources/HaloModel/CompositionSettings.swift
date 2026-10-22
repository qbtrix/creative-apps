// CompositionSettings.swift: what the New Composition sheet asks for (name,
// size, frame rate, duration in seconds) and the rules that make it valid.
// Linux-safe: no UI imports. The sheet edits a copy as a draft; HaloProject
// only ever builds a composition from settings that pass `isValid`. The rate
// is one of SuiteKernel's `FrameRate.common` (frame-rates FR-8).
import SuiteKernel

/// The settings a new composition is made from.
public struct CompositionSettings: Sendable, Hashable {
    /// The width and height a composition can have, in pixels.
    public static let sizeRange = 1...8192
    /// The longest composition, 24 hours; keeps the frame count far from Int.max.
    public static let maxDurationSeconds = 86_400.0

    public var name: String
    public var width: Int
    public var height: Int
    /// The exact rate, one of `FrameRate.common` while valid.
    public var frameRate: FrameRate
    public var durationSeconds: Double

    public init(name: String, width: Int = 1920, height: Int = 1080, frameRate: FrameRate, durationSeconds: Double = 10) {
        self.name = name
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.durationSeconds = durationSeconds
    }

    /// Settings at a whole rate, as before rates were rational.
    public init(name: String, width: Int = 1920, height: Int = 1080, framesPerSecond: Int = 30, durationSeconds: Double = 10) {
        self.init(name: name, width: width, height: height, frameRate: FrameRate(whole: framesPerSecond), durationSeconds: durationSeconds)
    }

    /// The whole rate, 30 for 29.97, for old callers; setting it makes the rate whole.
    public var framesPerSecond: Int {
        get { frameRate.nominal }
        set { frameRate = FrameRate(whole: newValue) }
    }

    /// These settings at `rate`, as the sheet's rate menu picks it.
    public func withFrameRate(_ rate: FrameRate) -> CompositionSettings {
        var copy = self
        copy.frameRate = rate
        return copy
    }

    /// The rate problem in words, naming every rate on the list.
    static var frameRateProblem: String {
        let names = FrameRate.common.map { String($0.description.dropLast(" fps".count)) }
        return "Frame rate must be \(names.dropLast().joined(separator: ", ")) or \(names.last ?? "") fps."
    }

    /// Why the settings can't make a composition, one line per problem, in
    /// form order; empty when they can.
    public var problems: [String] { fieldProblems.map(\.text) }

    /// Each problem with the sheet field it's about, in form order, so the
    /// sheet shows it next to that field.
    public var fieldProblems: [CompositionProblem] {
        var problems: [CompositionProblem] = []
        if name.trimmed.isEmpty { problems.append(.init(.name, "Enter a name.")) }
        let sizes = "\(Self.sizeRange.lowerBound) to \(Self.sizeRange.upperBound)"
        if !Self.sizeRange.contains(width) { problems.append(.init(.width, "Width must be \(sizes) pixels.")) }
        if !Self.sizeRange.contains(height) { problems.append(.init(.height, "Height must be \(sizes) pixels.")) }
        if !FrameRate.common.contains(frameRate) { problems.append(.init(.frameRate, Self.frameRateProblem)) }
        if !(durationSeconds > 0 && durationSeconds <= Self.maxDurationSeconds) {
            problems.append(.init(.duration, "Duration must be more than 0 seconds and at most 24 hours."))
        }
        return problems
    }

    /// Whether Create can make a composition from these settings.
    public var isValid: Bool { problems.isEmpty }

    /// The duration in whole frames, at least 1; nil while invalid.
    public var durationFrames: Int? {
        guard isValid else { return nil }
        return max(1, frameRate.frames(forDuration: durationSeconds))
    }
}

/// A field of the New Composition sheet.
public enum CompositionField: Sendable, Hashable, CaseIterable {
    case name, width, height, frameRate, duration
}

/// One reason the settings can't make a composition, and the field it's about.
public struct CompositionProblem: Sendable, Hashable {
    public var field: CompositionField
    public var text: String

    public init(_ field: CompositionField, _ text: String) {
        self.field = field
        self.text = text
    }
}

extension String {
    /// The string without leading and trailing whitespace.
    var trimmed: String { String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed()) }
}
