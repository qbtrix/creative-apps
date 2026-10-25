// ToneRules.swift (tone-controls TC-1 stubs, TC-5 bodies): ToneSettings turned
// into CoreRender's steps. `program` is the live list one display write folds
// in (suite-imaging's LiveToneSurface), `adjustments` the same steps on the
// CPU for export, `unsharp` the one sharpen pass both paths run first, and
// `auto` reads CoreRaster's AutoTone suggestion into the sliders. Both lists
// come from one private step list, so they can't drift. Linux-safe.
#if canImport(Glibc)
import Glibc  // log2
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import CoreColor
import CoreRaster
import CoreRender

public enum ToneRules {
    /// Sliders that can't render yet, with the reason the row and the command show.
    public static let waiting: [ToneSlider: String] = [.vibrance: "Vibrance waits on creative-core: vibrance on the GPU."]

    /// The live steps, one display write: the export steps, each as a program operation.
    public static func program(_ s: ToneSettings) -> [ToneProgram.Operation] {
        steps(s).map(ToneProgram.Operation.adjustment)
    }

    /// The export steps, the same as `program` on the CPU.
    public static func adjustments(_ s: ToneSettings) -> [ToneAdjustment] { steps(s) }

    /// The unsharp pass, nil at Amount 0: amount as a fraction, sigma the radius in pixels, threshold in 0...1.
    public static func unsharp(_ s: ToneSettings) -> (amount: Double, sigma: Double, threshold: Double)? {
        let amount = s.value(.sharpenAmount)
        guard amount > 0 else { return nil }
        return (amount / 100, s.value(.sharpenRadius), s.value(.sharpenThreshold) / 255)
    }

    /// Auto's suggestion read into white balance, exposure, whites and blacks; every other slider kept.
    /// Whites and Blacks invert the levels rule on the suggestion's points read in sRGB; Exposure is the
    /// stops the gamma moves mid grey, log2(0.18^(1/gamma) / 0.18). Each value is clamped to its range.
    public static func auto(_ a: AutoTone, keeping s: ToneSettings) -> ToneSettings {
        let white = TransferCurve.encode(Double(a.inWhite)), black = TransferCurve.encode(Double(a.inBlack))
        let gamma = Double(a.gamma)
        let stops = gamma.isFinite && gamma > 0 ? (1 / gamma - 1) * log2(midGrey) : 0
        let values: [(ToneSlider, Double)] = [
            (.temperature, Double(a.temperature)), (.tint, Double(a.tint)), (.exposure, stops),
            (.whites, white < 1 ? (1 - white) * levelsScale : 0), (.blacks, black > 0 ? -black * levelsScale : 0),
        ]
        return values.reduce(s) { $0.setting($1.0, to: clamped($1.1, $1.0)) }
    }

    /// Mid grey in linear light, the point Exposure's stops are read at.
    private static let midGrey = 0.18
    /// Whites and Blacks move a levels point at most a quarter of the range: slider 100 is 0.25.
    private static let levelsScale = 400.0

    /// `v` inside `slider`'s range, to the hundredth so sRGB rounding (encode(1) is 1 - 1e-16) leaves no
    /// stray value off neutral; a non-finite value reads neutral.
    private static func clamped(_ v: Double, _ slider: ToneSlider) -> Double {
        guard v.isFinite else { return slider.neutral }
        return min(max((v * 100).rounded() / 100, slider.range.lowerBound), slider.range.upperBound)
    }

    /// The one step list both paths run, each skipped at neutral: white balance, exposure, brightness,
    /// contrast, highlights and shadows, whites, blacks, saturation, then vibrance once it renders.
    private static func steps(_ s: ToneSettings) -> [ToneAdjustment] {
        var out: [ToneAdjustment] = []
        let temperature = Float(s.value(.temperature)), tint = Float(s.value(.tint))
        if temperature != 0 || tint != 0 { out.append(.whiteBalance(temperature: temperature, tint: tint)) }
        let exposure = Float(s.value(.exposure))
        if exposure != 0 { out.append(.exposure(stops: exposure)) }
        let brightness = s.value(.brightness)
        if brightness != 0 {
            // An sRGB midtone gamma with black and white fixed: +100 lifts the midtones about a stop, never clips.
            let gamma = Float(pow(2, brightness / 100))
            out.append(.levels(inBlack: 0, inWhite: 1, gamma: gamma, outBlack: 0, outWhite: 1, encoding: .sRGB))
        }
        let contrast = Float(s.value(.contrast))
        if contrast != 0 { out.append(.contrast(contrast)) }
        let highlights = Float(s.value(.highlights)), shadows = Float(s.value(.shadows))
        if highlights != 0 || shadows != 0 { out.append(.highlightsShadows(highlights: highlights, shadows: shadows)) }
        // Library's rule (LiveDevelop): sRGB levels moving a point at most a quarter of the range, so the black
        // point stays at or below 0.25 and the white point at or above 0.75, and levels never throws.
        let whites = s.value(.whites)
        if whites != 0 {
            let inWhite = whites > 0 ? 1 - whites / levelsScale : 1, outWhite = whites < 0 ? 1 + whites / levelsScale : 1
            out.append(.levels(inBlack: 0, inWhite: Float(inWhite), gamma: 1, outBlack: 0, outWhite: Float(outWhite),
                               encoding: .sRGB))
        }
        let blacks = s.value(.blacks)
        if blacks != 0 {
            let inBlack = blacks < 0 ? -blacks / levelsScale : 0, outBlack = blacks > 0 ? blacks / levelsScale : 0
            out.append(.levels(inBlack: Float(inBlack), inWhite: 1, gamma: 1, outBlack: Float(outBlack), outWhite: 1,
                               encoding: .sRGB))
        }
        let saturation = Float(s.value(.saturation))
        if saturation != 0 { out.append(.hueSaturation(hue: 0, saturation: saturation, lightness: 0)) }
        let vibrance = Float(s.value(.vibrance))
        if vibrance != 0 && waiting[.vibrance] == nil { out.append(.vibrance(vibrance)) }
        return out
    }
}
