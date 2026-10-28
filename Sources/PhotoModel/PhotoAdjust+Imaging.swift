// PhotoAdjust+Imaging.swift: Photo's AdjustmentSettings over SuiteImaging's
// AdjustSettings (suite-imaging IM-7). The settings store one AdjustSettings
// (`imaging`) beside blur and the switches; this file reads Photo's Float
// values out of it, compiles the enabled sections to ImagingProgram's steps
// and runs them, and keeps the stored form Photo's: the same keys, Floats
// written as Floats, `enabled` in AdjustmentKind order, and output levels
// written only when they move off 0 and 1, so a file from before them opens
// with neutral output levels and saves again byte for byte; `tone` likewise
// only when off neutral (tone-controls PT-1). Tone's steps (ToneRules) run
// before every section, and its sharpen is one unsharp pass over the base
// before them (tone-controls PT-3). Hue/saturation
// stays Photo's own matrix (HueSaturation.swift): the GPU route and the live
// tone route run that matrix, and they move together (IM-8). `kinds` (AJ-8)
// run after it and are stored under "kinds" only when there are any. Linux-safe.
import CoreRaster
import CoreRender
import SuiteImaging

extension AdjustmentSettings {
    /// Stops.
    public var exposure: Float { Float(imaging.exposure) }
    public var blackPoint: Float { Float(imaging.levels.inputBlack) }
    public var whitePoint: Float { Float(imaging.levels.inputWhite) }
    public var gamma: Float { Float(imaging.levels.gamma) }
    /// Levels' output black and white; 0 and 1 until something sets them.
    public var outputBlack: Float { Float(imaging.levels.outputBlack) }
    public var outputWhite: Float { Float(imaging.levels.outputWhite) }
    /// The tone curve's control points, x strictly increasing.
    public var curvePoints: [CurvePoint] { imaging.curve.points.map { CurvePoint(x: Float($0.x), y: Float($0.y)) } }
    /// Degrees.
    public var hue: Double { imaging.hueSaturation.hue }
    public var saturation: Double { imaging.hueSaturation.saturation }
    public var lightness: Double { imaging.hueSaturation.lightness }

    static func imagingCurve(_ points: [CurvePoint]) -> AdjustCurve {
        AdjustCurve(points: points.map { AdjustCurvePoint(x: Double($0.x), y: Double($0.y)) })
    }

    /// The tone section's steps (temperature, tint, vibrance and the rest), which run before every section.
    var toneSteps: [ToneAdjustment] { ToneRules.adjustments(tone) }

    /// The tone section's sharpen: one unsharp pass over the base before every step, nil when off.
    var unsharp: (amount: Double, sigma: Double, threshold: Double)? { ToneRules.unsharp(tone) }

    /// ImagingProgram's steps: `tone` (the tone section's own steps when nil) first, then the enabled
    /// sections among `kinds`.
    func imagingSteps(
        _ kinds: Set<AdjustmentKind> = Set(AdjustmentKind.allCases), tone: [ToneAdjustment]? = nil
    ) -> [ToneAdjustment] {
        let on = kinds.intersection(enabled)
        let neutral = AdjustSettings.neutral
        let sections = AdjustSettings(
            exposure: on.contains(.exposure) ? imaging.exposure : neutral.exposure,
            levels: on.contains(.levels) ? imaging.levels : neutral.levels,
            curve: on.contains(.curves) ? imaging.curve : neutral.curve,
            hueSaturation: on.contains(.hueSaturation) ? imaging.hueSaturation : neutral.hueSaturation)
        return ImagingProgram.adjustments(sections, tone: tone ?? toneSteps)
            + AdjustKinds.adjustments(self.kinds.filter { kinds.contains($0.adjustment) })
    }

    /// Every enabled section's step, as the render runs them.
    var imagingSteps: [ToneAdjustment] { imagingSteps() }

    /// `steps` run in order on `buffer` by CoreRender's CPU backend, a hue/saturation
    /// step through Photo's matrix. Throws `RasterError.invalid` when a step fails.
    func runImaging(_ steps: [ToneAdjustment], on buffer: PixelBuffer) throws -> PixelBuffer {
        var result = buffer, run: [ToneAdjustment] = []
        for step in steps {
            if case .hueSaturation = step {
                result = try Self.runCPU(run, on: result).hueSaturation(hue: hue, saturation: saturation, lightness: lightness)
                run = []
            } else {
                run.append(step)
            }
        }
        return try Self.runCPU(run, on: result)
    }

    private static func runCPU(_ steps: [ToneAdjustment], on buffer: PixelBuffer) throws -> PixelBuffer {
        guard !steps.isEmpty else { return buffer }
        let cpu = CPUBackend(name: "photo-imaging")
        do {
            var surface = try cpu.surface(buffer)
            defer { cpu.release(surface) }
            for step in steps {
                let next = try cpu.adjusted(surface, step)
                cpu.release(surface)
                surface = next
            }
            return try cpu.read(surface)
        } catch RenderError.raster(let message) {
            throw RasterError.invalid(message)
        }
    }
}

extension AdjustmentSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case exposure, blackPoint, whitePoint, gamma, outputBlack, outputWhite, curvePoints, blurSigma
        case hue, saturation, lightness, enabled, tone, kinds
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let levels = AdjustLevels(
            inputBlack: Double(try c.decode(Float.self, forKey: .blackPoint)),
            inputWhite: Double(try c.decode(Float.self, forKey: .whitePoint)),
            gamma: Double(try c.decode(Float.self, forKey: .gamma)),
            outputBlack: Double(try c.decodeIfPresent(Float.self, forKey: .outputBlack) ?? 0),
            outputWhite: Double(try c.decodeIfPresent(Float.self, forKey: .outputWhite) ?? 1))
        let hueSaturation = AdjustHueSaturation(
            hue: try c.decode(Double.self, forKey: .hue),
            saturation: try c.decode(Double.self, forKey: .saturation),
            lightness: try c.decode(Double.self, forKey: .lightness))
        self.init(
            imaging: AdjustSettings(
                exposure: Double(try c.decode(Float.self, forKey: .exposure)), levels: levels,
                curve: Self.imagingCurve(try c.decode([CurvePoint].self, forKey: .curvePoints)),
                hueSaturation: hueSaturation),
            blurSigma: try c.decode(Double.self, forKey: .blurSigma),
            enabled: Set(try c.decode([AdjustmentKind].self, forKey: .enabled)),
            tone: try c.decodeIfPresent(ToneSettings.self, forKey: .tone) ?? .neutral,
            kinds: try c.decodeIfPresent([ImagingKind].self, forKey: .kinds) ?? [])
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(exposure, forKey: .exposure)
        try c.encode(blackPoint, forKey: .blackPoint)
        try c.encode(whitePoint, forKey: .whitePoint)
        try c.encode(gamma, forKey: .gamma)
        if outputBlack != 0 { try c.encode(outputBlack, forKey: .outputBlack) }
        if outputWhite != 1 { try c.encode(outputWhite, forKey: .outputWhite) }
        try c.encode(curvePoints, forKey: .curvePoints)
        try c.encode(blurSigma, forKey: .blurSigma)
        try c.encode(hue, forKey: .hue)
        try c.encode(saturation, forKey: .saturation)
        try c.encode(lightness, forKey: .lightness)
        try c.encode(AdjustmentKind.sections.filter(enabled.contains), forKey: .enabled)
        if !tone.isNeutral(nil) { try c.encode(tone, forKey: .tone) }
        if !kinds.isEmpty { try c.encode(kinds, forKey: .kinds) }
    }
}
