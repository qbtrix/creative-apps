// DocumentSetup.swift (document-setup DS-1 stubs, DS-3 bodies): what a new document asks for and what
// Document Settings edits later: a size in a length unit at a resolution, a background, and, for timed
// apps, a frame rate and a duration in seconds. Every rule here is total and never traps.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The units a document's size is typed in: pixels, points (1/72 in), inches, centimetres and millimetres.
public enum LengthUnit: String, Hashable, Sendable, Codable, CaseIterable {
    case px, pt, inch = "in", cm, mm

    /// Centimetres in an inch, exactly.
    static let cmPerInch = 2.54

    /// How many of this unit make an inch; nil for px, whose inch is the document's resolution.
    var perInch: Double? {
        switch self {
        case .px: nil
        case .pt: 72
        case .inch: 1
        case .cm: Self.cmPerInch
        case .mm: Self.cmPerInch * 10
        }
    }
}

/// A new document's background: white, transparent, or a colour as "#RRGGBB" (or "#RRGGBBAA").
/// It codes as one string: "white", "transparent" or the hex.
public enum DocumentBackground: Hashable, Sendable, Codable {
    case white, transparent, color(hex: String)

    /// "white", "transparent", or a hex colour; nil for anything else.
    public init?(parsing text: String) {
        switch text {
        case "white": self = .white
        case "transparent": self = .transparent
        default:
            let digits = text.dropFirst().uppercased()
            guard text.hasPrefix("#"), digits.count == 6 || digits.count == 8, digits.allSatisfy(\.isHexDigit) else { return nil }
            self = digits.count == 8 && digits.hasSuffix("00") ? .transparent : .color(hex: "#" + digits)
        }
    }

    /// The string this background codes as.
    public var text: String {
        switch self {
        case .white: "white"
        case .transparent: "transparent"
        case .color(let hex): hex
        }
    }

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
    public var pixelSize: (width: Int, height: Int) { (pixels(width), pixels(height)) }

    /// `value` in `unit` as whole pixels, nearest; 0 for a value that isn't a finite size.
    func pixels(_ value: Double) -> Int {
        let exact = unit.perInch.map { value * resolution / $0 } ?? value
        guard exact.isFinite else { return 0 }
        return Int(min(max(exact.rounded(), 0), Double(Int32.max)))
    }

    /// The same pixels typed in `unit`; unchanged while the resolution isn't a usable size.
    public func converted(to unit: LengthUnit) -> DocumentSetup {
        guard resolution.isFinite, resolution > 0 else { return self }
        func typed(_ value: Double) -> Double {
            let inches = self.unit.perInch.map { value / $0 } ?? value / resolution
            return unit.perInch.map { inches * $0 } ?? inches * resolution
        }
        var next = self
        (next.width, next.height, next.unit) = (typed(width), typed(height), unit)
        return next
    }

    /// Width and height swapped: portrait to landscape and back.
    public func swapped() -> DocumentSetup {
        var next = self
        (next.width, next.height) = (height, width)
        return next
    }

    /// Each field's problem against `limits`, in form order; empty when the setup can make a document.
    public func problems(_ limits: DocumentLimits) -> [SetupProblem] {
        var found: [SetupProblem] = []
        let (w, h) = pixelSize, side = 1...max(1, limits.maxSide)
        if !side.contains(w) { found.append(SetupProblem(.width, "Width must be 1 to \(limits.maxSide) px.")) }
        if !side.contains(h) { found.append(SetupProblem(.height, "Height must be 1 to \(limits.maxSide) px.")) }
        if !(resolution.isFinite && (1...10_000).contains(resolution)) {
            found.append(SetupProblem(.resolution, "Resolution must be 1 to 10000 ppi."))
        }
        if let rates = limits.rates, !rates.contains(where: { $0 == frameRate }) {
            found.append(SetupProblem(.frameRate, "Pick a frame rate this app offers."))
        }
        if let most = limits.maxSeconds, !(durationSeconds.map { $0 > 0 && $0 <= most } ?? false) {
            let shown = most.rounded() == most && abs(most) < 1e15 ? String(Int(most)) : String(most)
            found.append(SetupProblem(.duration, "Duration must be more than 0 and at most \(shown) seconds."))
        }
        if case .color(let hex) = background, DocumentBackground(parsing: hex) == nil {
            found.append(SetupProblem(.background, "Pick a valid background color."))
        }
        return found
    }
}
