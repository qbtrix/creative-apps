// FrameRate.swift (frame-rates FR-1 stubs, FR-3 bodies): the one frame-rate list every timed app reads, as
// exact rationals (29.97 is 30000/1001), and the one rounding rule from seconds to whole frames.
// Every function is total and never traps.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A frame rate as a reduced fraction of frames per second: 24/1, or 30000/1001 for 29.97.
public struct FrameRate: Hashable, Sendable, Codable, CustomStringConvertible {
    /// Frames per `denominator` seconds: 30000 for 29.97; the denominator is always above 0.
    public let numerator: Int, denominator: Int

    /// The rate `numerator / denominator`, stored reduced with a positive denominator.
    public init(numerator: Int, denominator: Int) {
        self.numerator = numerator
        self.denominator = max(1, denominator)
    }

    /// A whole rate: `whole` frames per second.
    public init(whole: Int) { self.init(numerator: whole, denominator: 1) }

    /// The nine rates a menu offers, slowest first: 12, 23.976, 24, 25, 29.97, 30, 50, 59.94 and 60.
    public static let common: [FrameRate] = []

    /// True when the rate is a whole number of frames per second.
    public var isWhole: Bool { false }

    /// True at 29.97 and 59.94, whose timecode is drop-frame.
    public var isDropFrame: Bool { false }

    /// Timecode's frames per second: the rate rounded, 30 for 29.97.
    public var nominal: Int { 0 }

    /// "29.97 fps": the menu title.
    public var description: String { "" }

    /// The time `frame` starts at, in seconds.
    public func seconds(ofFrame frame: Int) -> Double { 0 }

    /// The frame nearest `s` seconds, ties up.
    public func frame(atSeconds s: Double) -> Int { 0 }

    /// A duration of `s` seconds in whole frames by the same rounding: 10 s at 29.97 is 300.
    public func frames(forDuration s: Double) -> Int { 0 }

    enum CodingKeys: String, CodingKey { case num, den }

    /// Decodes `{num, den}`, a legacy whole `Int`, or a decimal that names a rate in `common` (29.97).
    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.init(numerator: try keyed.decode(Int.self, forKey: .num), denominator: try keyed.decode(Int.self, forKey: .den))
    }

    /// Encodes `{num, den}`.
    public func encode(to encoder: Encoder) throws {
        var keyed = encoder.container(keyedBy: CodingKeys.self)
        try keyed.encode(numerator, forKey: .num)
        try keyed.encode(denominator, forKey: .den)
    }
}
