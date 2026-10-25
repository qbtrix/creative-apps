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

    /// The rate `numerator / denominator`, stored reduced with a positive denominator (a 0 denominator reads as 1).
    public init(numerator: Int, denominator: Int) {
        let den = denominator == 0 ? 1 : denominator
        var (n, d) = (numerator.magnitude, den.magnitude)
        var (a, b) = (n, d)
        while b != 0 { (a, b) = (b, a % b) }
        if a > 1 { (n, d) = (n / a, d / a) }
        let magnitude = Int(clamping: n)
        self.numerator = (numerator < 0) != (den < 0) ? -magnitude : magnitude
        self.denominator = Int(clamping: d)
    }

    /// A whole rate: `whole` frames per second.
    public init(whole: Int) { self.init(numerator: whole, denominator: 1) }

    /// The nine rates a menu offers, slowest first: 12, 23.976, 24, 25, 29.97, 30, 50, 59.94 and 60.
    public static let common: [FrameRate] = [
        FrameRate(whole: 12), FrameRate(numerator: 24000, denominator: 1001), FrameRate(whole: 24), FrameRate(whole: 25),
        FrameRate(numerator: 30000, denominator: 1001), FrameRate(whole: 30), FrameRate(whole: 50),
        FrameRate(numerator: 60000, denominator: 1001), FrameRate(whole: 60),
    ]

    /// True when the rate is a whole number of frames per second.
    public var isWhole: Bool { denominator == 1 }

    /// True at 29.97 and 59.94, whose timecode is drop-frame.
    public var isDropFrame: Bool { denominator == 1001 && (numerator == 30000 || numerator == 60000) }

    /// Timecode's frames per second: the rate rounded, 30 for 29.97; 0 for a rate at or below 0.
    public var nominal: Int {
        guard numerator > 0 else { return 0 }
        let rest = numerator % denominator
        return numerator / denominator + (rest >= denominator - rest ? 1 : 0)
    }

    /// The rate as a `Double`: 29.97002997 for 30000/1001.
    var value: Double { Double(numerator) / Double(denominator) }

    /// "29.97 fps": the menu title, at most three decimals with trailing zeros dropped.
    public var description: String {
        guard numerator > 0, numerator < Int.max / 1000 else { return "\(max(0, nominal)) fps" }
        let scaled = numerator * 1000, rest = scaled % denominator
        let thousandths = scaled / denominator + (rest >= denominator - rest ? 1 : 0)
        var decimals = String(thousandths % 1000)
        decimals = String(repeating: "0", count: max(0, 3 - decimals.count)) + decimals
        while decimals.hasSuffix("0") { decimals.removeLast() }
        return "\(thousandths / 1000)\(decimals.isEmpty ? "" : "." + decimals) fps"
    }

    /// The time `frame` starts at, in seconds; 0 for a rate at or below 0.
    public func seconds(ofFrame frame: Int) -> Double { numerator > 0 ? Double(frame) * Double(denominator) / Double(numerator) : 0 }

    /// The frame nearest `s` seconds, ties up; 0 for a time that isn't finite or a rate at or below 0.
    public func frame(atSeconds s: Double) -> Int {
        let exact = s * Double(numerator) / Double(denominator)
        let rounded = (exact + 0.5).rounded(.down)
        guard rounded.isFinite else { return 0 }
        return rounded >= 9e18 ? Int.max : rounded <= -9e18 ? Int.min : Int(rounded)
    }

    /// A duration of `s` seconds in whole frames by the same rounding: 10 s at 29.97 is 300.
    public func frames(forDuration s: Double) -> Int { frame(atSeconds: s) }

    enum CodingKeys: String, CodingKey { case num, den }

    /// Decodes `{num, den}`, a legacy whole `Int`, or a decimal that names a rate in `common` (29.97).
    public init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
            let (num, den) = (try keyed.decode(Int.self, forKey: .num), try keyed.decode(Int.self, forKey: .den))
            guard num > 0, den > 0 else {
                throw DecodingError.dataCorruptedError(forKey: .den, in: keyed, debugDescription: "A frame rate's num and den are above 0.")
            }
            self.init(numerator: num, denominator: den)
            return
        }
        let single = try decoder.singleValueContainer()
        if let whole = try? single.decode(Int.self), whole > 0 { self.init(whole: whole); return }
        let decimal = try single.decode(Double.self)
        guard let rate = Self.common.first(where: { abs($0.value - decimal) < 0.005 }) else {
            throw DecodingError.dataCorruptedError(in: single, debugDescription: "\(decimal) fps is not a common frame rate.")
        }
        self = rate
    }

    /// Encodes `{num, den}`.
    public func encode(to encoder: Encoder) throws {
        var keyed = encoder.container(keyedBy: CodingKeys.self)
        try keyed.encode(numerator, forKey: .num)
        try keyed.encode(denominator, forKey: .den)
    }
}
