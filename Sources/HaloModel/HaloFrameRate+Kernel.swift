// HaloFrameRate+Kernel.swift (frame-rates FR-8): Halo's adapter onto SuiteKernel's `FrameRate`, the one
// rate list and rounding rule. A composition holds an exact rational rate; `framesPerSecond` stays as its
// whole (nominal) rate for old callers. Its file keeps writing `"framesPerSecond"` and adds `"frameRate":
// {num, den}` only for a rate that isn't whole, so every old file re-saves byte for byte. A render plan times
// each frame by the exact rate, and `setFrameRate` sets it to one of the kernel's list. Linux-safe: no UI imports.
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
}
