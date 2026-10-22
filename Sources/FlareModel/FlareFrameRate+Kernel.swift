// FlareFrameRate+Kernel.swift (frame-rates FR-10): Flare's one adapter between SuiteKernel's `FrameRate` and
// FlareCore's `SceneRate`, both exact fractions (29.97 is 30000/1001). The scene stores the rate as is, so the Lottie
// exporter writes `fr` 23.976, never 24. `scene.set-frame-rate` sets the selected scene's rate and, given a length in
// seconds, its duration in whole frames by the kernel's rounding (10 s at 23.976 is 240 frames). The inspector's
// `.setSceneTiming(rate:durationFrames:)` routes here with the picked rate as is (FR-10b), never its whole number.
// Linux-safe.
import FlareCore
import SuiteKernel

extension FrameRate {
    /// The kernel rate of a scene's rate: 30000/1001 for 29.97.
    public init(_ rate: SceneRate) { self.init(numerator: rate.numerator, denominator: rate.denominator) }

    /// The exact rate a scene stores and Lottie's `fr` is written from: 24000/1001, not 24.
    public var sceneRate: SceneRate { SceneRate(numerator: numerator, denominator: denominator) }
}

extension Scene {
    /// The scene's rate as the kernel's `FrameRate`; an old `"fps": 24` file reads 24/1.
    public var frameRate: FrameRate { FrameRate(rate) }
}

extension FlareWorkspace {
    /// `scene.set-frame-rate`'s params: the rate as `{num, den}`, and an optional length in seconds.
    public struct FrameRateParams: Codable, Sendable {
        public var num: Int, den: Int
        public var seconds: Double?
    }

    static let setFrameRate = CommandSpec<FlareWorkspace>.typed(
        "scene.set-frame-rate", title: "Set Frame Rate",
        summary: "Sets the selected scene's frame rate as an exact fraction, and its length when seconds are given.", kind: .edit,
        params: FrameRateParams.self,
        schema: .object(
            ["num": .integer("Frames per `den` seconds: 24000 for 23.976.", minimum: 1),
             "den": .integer("The rate's denominator: 1 for a whole rate, 1001 for 23.976, 29.97 and 59.94.", minimum: 1),
             "seconds": .optional(.number("The new length in seconds, rounded to whole frames; left out, the frame count stays.", minimum: 0))],
            required: ["num", "den", "seconds"]),
        example: .object(["num": .number(24000), "den": .number(1001), "seconds": .number(2)]),
        availability: { noScene($0).map(Availability.unavailable) ?? .available }) { w, p in
        try w.attempt("scene.set-frame-rate") { $0.setSceneFrameRate(FrameRate(numerator: p.num, denominator: p.den), seconds: p.seconds) }
        return JSONValue.object([:])
    }

    /// Sets the selected scene's rate to `rate` in one undo step, and its length to `seconds` in whole frames
    /// (`FrameRate.frames(forDuration:)`) when given; a rate the format refuses, a length out of range or one that
    /// cuts off a label changes nothing but `layerError`.
    public mutating func setSceneFrameRate(_ rate: FrameRate, seconds: Double? = nil) {
        guard let scene = selectedScene else { return refuse(.noDocument) }
        let exact = rate.sceneRate
        guard exact.isValid else { return refuse(.command(.invalidFPS(rate.numerator))) }
        let frames = seconds.map { rate.frames(forDuration: $0) } ?? scene.durationFrames
        let range = NewDocumentSpec.durationRange
        if seconds != nil, !range.contains(frames) {
            return refuse(.refused("Duration must be \(range.lowerBound) to \(range.upperBound) frames."))
        }
        if let last = scene.labels.values.max(), last > frames {
            return refuse(.refused("Length must reach frame \(last), where a label sits."))
        }
        applyGroup("Set Frame Rate") {
            try $0.perform(SetSceneTiming(sceneID: scene.id, fps: exact.nominal, durationFrames: frames, rate: exact))
        }
        // 24 to 23.976 keeps the whole rate, so `step` sees no change: a running play rebases its clock here.
        if isPlaying, canPlay { playClock = playbackRate.seconds(ofFrame: currentFrame) }
    }

    /// The Scene inspector's rate and length: a new rate goes through `setSceneFrameRate` exactly, length and all,
    /// in one undo step; the same rate keeps it and sets only the length.
    public mutating func setSceneTiming(_ rate: FrameRate, durationFrames: Int) {
        guard let scene = selectedScene, rate != scene.frameRate else {
            return setSceneTiming(fps: selectedScene?.fps ?? rate.nominal, durationFrames: durationFrames)
        }
        let keepsLength = durationFrames == scene.durationFrames
        setSceneFrameRate(rate, seconds: keepsLength ? nil : rate.seconds(ofFrame: durationFrames))
    }
}
