// HaloFrameRate+Kernel.swift (frame-rates FR-8): Halo's adapter onto SuiteKernel's `FrameRate`, the one
// rate list and rounding rule. A composition holds an exact rational rate; `framesPerSecond` stays as its
// whole (nominal) rate for old callers. Its file keeps writing `"framesPerSecond"` and adds `"frameRate":
// {num, den}` only for a rate that isn't whole, so every old file re-saves byte for byte. A render plan times
// each frame by the exact rate, and `setFrameRate` sets it to one of the kernel's list (FR-8b: also by the
// command `composition.set-frame-rate`). `HaloMovieClock` is the movie's clock in whole ticks, so the movie
// writer times frame n at n x den / num s exactly. Linux-safe: no UI imports.
import SuiteKernel

extension HaloComposition {
    /// A composition at a whole rate, as before rates were rational.
    public init(
        id: String, name: String, width: Int, height: Int, framesPerSecond: Int, durationFrames: Int,
        layers: [HaloLayer] = []
    ) {
        self.init(
            id: id, name: name, width: width, height: height, frameRate: FrameRate(whole: framesPerSecond),
            durationFrames: durationFrames, layers: layers)
    }

    /// The whole rate: 30 for 29.97 (the rate timecode counts by); setting it makes the rate whole.
    public var framesPerSecond: Int {
        get { frameRate.nominal }
        set { frameRate = FrameRate(whole: newValue) }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, width, height, framesPerSecond, frameRate, durationFrames, layers, playheadFrame
    }

    /// Reads `frameRate` when the file has it, else the whole `framesPerSecond` every old file has. Keys are
    /// read in the file's order, so a damaged file names the first one missing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id), name = try c.decode(String.self, forKey: .name)
        let width = try c.decode(Int.self, forKey: .width), height = try c.decode(Int.self, forKey: .height)
        let whole = try c.decode(Int.self, forKey: .framesPerSecond)
        self.init(
            id: id, name: name, width: width, height: height,
            frameRate: try c.decodeIfPresent(FrameRate.self, forKey: .frameRate) ?? FrameRate(whole: whole),
            durationFrames: try c.decode(Int.self, forKey: .durationFrames),
            layers: try c.decode([HaloLayer].self, forKey: .layers))
        playheadFrame = try c.decode(Int.self, forKey: .playheadFrame)
    }

    /// Writes the whole rate as `framesPerSecond`, and `frameRate` only when the rate isn't whole.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(framesPerSecond, forKey: .framesPerSecond)
        if !frameRate.isWhole { try c.encode(frameRate, forKey: .frameRate) }
        try c.encode(durationFrames, forKey: .durationFrames)
        try c.encode(layers, forKey: .layers)
        try c.encode(playheadFrame, forKey: .playheadFrame)
    }
}

extension HaloRenderPlan {
    /// The time `frame` of the render starts at, by the exact rate: frame 299 at 29.97 is 299 x 1001 / 30000 s.
    public func seconds(ofFrame frame: Int) -> Double { frameRate.seconds(ofFrame: frame) }

    /// The movie's clock at the plan's exact rate; nil for a rate a movie can't count in 32-bit ticks.
    public var movieClock: HaloMovieClock? { HaloMovieClock(frameRate) }
}

/// A movie's clock for one rate, in whole ticks: frame n starts at n x den ticks of 1 / num s (299 x 1001 of
/// 1 / 30000 s at 29.97), and the track counts in `trackTimescale`, the smallest whole multiple of num that is
/// at least 600 (600 at 24, 30000 at 29.97), so every frame lands on a tick.
public struct HaloMovieClock: Equatable, Sendable {
    /// Ticks per second a frame's time is written in: the rate's numerator.
    public let frameTimescale: Int32
    /// Ticks one frame lasts: the rate's denominator.
    public let frameTicks: Int64
    /// Ticks per second of the track and the movie.
    public let trackTimescale: Int32

    /// Nil for a rate with a part below 1, or a numerator past 32 bits.
    public init?(_ rate: FrameRate) {
        guard rate.numerator > 0, rate.denominator > 0, let num = Int32(exactly: rate.numerator) else { return nil }
        let multiple = max(1, (600 + rate.numerator - 1) / rate.numerator)
        let track = num.multipliedReportingOverflow(by: Int32(clamping: multiple))
        frameTimescale = num
        frameTicks = Int64(rate.denominator)
        trackTimescale = track.overflow ? num : track.partialValue
    }

    /// Where frame `frame` starts (and frame `frame - 1` ends): `value` ticks of 1 / `timescale` s; nil for a
    /// negative frame or one past 64-bit ticks.
    public func time(ofFrame frame: Int) -> (value: Int64, timescale: Int32)? {
        guard frame >= 0 else { return nil }
        let ticks = Int64(frame).multipliedReportingOverflow(by: frameTicks)
        return ticks.overflow ? nil : (ticks.partialValue, frameTimescale)
    }
}

extension HaloProject {
    /// Sets the selected composition's rate to one of `FrameRate.common`; its frames, keys and spans stay.
    /// One step, "Set Frame Rate"; false for a rate off the list, the same rate, or no composition.
    @discardableResult
    public mutating func setFrameRate(_ rate: FrameRate) -> Bool {
        guard FrameRate.common.contains(rate), let id = selectedCompositionID,
            selectedComposition?.frameRate != rate
        else { return false }
        return edit("Set Frame Rate", control: "halo.inspector.composition.frameRate") { doc in
            guard let index = doc.compositions.firstIndex(where: { $0.id == id }) else { return }
            doc.compositions[index].frameRate = rate
        }
    }

    /// `composition.set-frame-rate`: `setFrameRate` by command, answering the rate set.
    static let frameRateSpecs: [CommandSpec<HaloProject>] = [
        .typed("composition.set-frame-rate", title: "Set Frame Rate",
               summary: "Sets the selected composition's frame rate to one of the nine rates; its frames stay.", kind: .edit,
               params: RateParams.self,
               schema: .object(["num": .integer("Frames per den seconds.", minimum: 1), "den": .integer("Seconds per num frames.", minimum: 1)],
                               required: ["den", "num"]),
               example: .object(["num": .number(30000), "den": .number(1001)]),
               availability: { $0.unavailableHelp(for: .duplicateComposition).map(Availability.unavailable) ?? .available }
        ) { p, o in try p.runSetFrameRate(o) },
    ]

    /// The rate `{num, den}`, as `composition.set-frame-rate` takes it.
    struct RateParams: Decodable, Sendable { var num: Int; var den: Int }

    /// Sets the selected composition's rate: refused off the nine rates; the same rate is no step.
    mutating func runSetFrameRate(_ o: RateParams) throws -> JSONValue {
        let id = "composition.set-frame-rate"
        if let why = unavailableHelp(for: .duplicateComposition) { throw CatalogError.unavailable(id: id, why: why) }
        let rate = FrameRate(numerator: o.num, denominator: o.den)
        guard FrameRate.common.contains(rate) else { throw CatalogError.failed(id: id, message: CompositionSettings.frameRateProblem) }
        setFrameRate(rate)
        return .object(["num": .number(Double(rate.numerator)), "den": .number(Double(rate.denominator))])
    }
}
