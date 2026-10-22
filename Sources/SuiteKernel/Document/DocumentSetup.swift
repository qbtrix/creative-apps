// DocumentSetup.swift (document-setup DS-1 stubs, DS-3 bodies): what a new document asks for and what
// Document Settings edits later: a size in a length unit at a resolution, a background, and, for timed
// apps, a frame rate and a duration in seconds. Every rule here is total and never traps.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The units a document's size is typed in: pixels, points (1/72 in), inches, centimetres and millimetres.
public enum LengthUnit: String, Hashable, Sendable, Codable, CaseIterable { case px, pt, inch = "in", cm, mm }

/// A new document's background: white, transparent, or a colour as "#RRGGBB" (or "#RRGGBBAA").
/// It codes as one string: "white", "transparent" or the hex.
public enum DocumentBackground: Hashable, Sendable, Codable {
    case white, transparent, color(hex: String)

    /// "white", "transparent", or a hex colour; nil for anything else.
    public init?(parsing text: String) { return nil }

    /// The string this background codes as.
    public var text: String { "white" }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = DocumentBackground(parsing: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "\(text) is not white, transparent or #RRGGBB."))
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        try single.encode(text)
    }
}

/// What an app allows: the longest side in pixels, its frame rates and its longest duration (nil for an
/// untimed app).
public struct DocumentLimits: Hashable, Sendable {
    public var maxSide: Int; public var rates: [FrameRate]?; public var maxSeconds: Double?
    public init(maxSide: Int = 16_384, rates: [FrameRate]? = nil, maxSeconds: Double? = nil) {
        (self.maxSide, self.rates, self.maxSeconds) = (maxSide, rates, maxSeconds)
    }
}

/// The sheet field a problem is about.
public enum SetupField: String, Hashable, Sendable { case width, height, resolution, frameRate, duration, background }

/// One reason the setup can't make a document, on the field it is about.
public struct SetupProblem: Hashable, Sendable {
    public var field: SetupField; public var text: String
    public init(_ field: SetupField, _ text: String) { (self.field, self.text) = (field, text) }
}

/// A document's size, resolution, background and, for timed apps, rate and duration. In JSON the
/// duration is `duration`; a missing unit is px, resolution 72 and background white.
public struct DocumentSetup: Hashable, Sendable, Codable {
    public var width, height: Double; public var unit: LengthUnit; public var resolution: Double
    public var background: DocumentBackground
    public var frameRate: FrameRate?; public var durationSeconds: Double?

    public init(width: Double, height: Double, unit: LengthUnit = .px, resolution: Double = 72, background: DocumentBackground = .white,
                frameRate: FrameRate? = nil, durationSeconds: Double? = nil) {
        (self.width, self.height, self.unit, self.resolution, self.background) = (width, height, unit, resolution, background)
        (self.frameRate, self.durationSeconds) = (frameRate, durationSeconds)
    }

    enum CodingKeys: String, CodingKey { case width, height, unit, resolution, background, frameRate, duration }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(width: try c.decode(Double.self, forKey: .width), height: try c.decode(Double.self, forKey: .height),
                  unit: try c.decodeIfPresent(LengthUnit.self, forKey: .unit) ?? .px,
                  resolution: try c.decodeIfPresent(Double.self, forKey: .resolution) ?? 72,
                  background: try c.decodeIfPresent(DocumentBackground.self, forKey: .background) ?? .white,
                  frameRate: try c.decodeIfPresent(FrameRate.self, forKey: .frameRate),
                  durationSeconds: try c.decodeIfPresent(Double.self, forKey: .duration))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(width, forKey: .width); try c.encode(height, forKey: .height); try c.encode(unit, forKey: .unit)
        try c.encode(resolution, forKey: .resolution); try c.encode(background, forKey: .background)
        try c.encodeIfPresent(frameRate, forKey: .frameRate); try c.encodeIfPresent(durationSeconds, forKey: .duration)
    }

    /// The size in whole pixels at `resolution`: px as typed, other units through inches.
    public var pixelSize: (width: Int, height: Int) { (0, 0) }

    /// The same pixels typed in `unit`.
    public func converted(to unit: LengthUnit) -> DocumentSetup { self }

    /// Width and height swapped: portrait to landscape and back.
    public func swapped() -> DocumentSetup { self }

    /// Each field's problem against `limits`, in form order; empty when the setup can make a document.
    public func problems(_ limits: DocumentLimits) -> [SetupProblem] { [] }
}
