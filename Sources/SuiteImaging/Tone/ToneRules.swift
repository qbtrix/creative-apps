// ToneRules.swift (tone-controls TC-1 stubs, TC-5 bodies): ToneSettings turned
// into CoreRender's steps. `program` is the live list one display write folds
// in (suite-imaging's LiveToneSurface), `adjustments` the same steps on the
// CPU for export, `unsharp` the one sharpen pass both paths run first, and
// `auto` reads CoreRaster's AutoTone suggestion into the sliders. TC-1 stubs:
// the lists are empty, `unsharp` is nil and `auto` returns its input. Linux-safe.
import CoreRaster
import CoreRender

public enum ToneRules {
    /// Sliders that can't render yet, with the reason the row and the command show.
    public static let waiting: [ToneSlider: String] = [.vibrance: "Vibrance waits on creative-core: vibrance on the GPU."]

    /// The live steps, one display write. Stub: empty until TC-5.
    public static func program(_ s: ToneSettings) -> [ToneProgram.Operation] { [] }

    /// The export steps, the same as `program` on the CPU. Stub: empty until TC-5.
    public static func adjustments(_ s: ToneSettings) -> [ToneAdjustment] { [] }

    /// The unsharp pass, nil at Amount 0. Stub: nil until TC-5.
    public static func unsharp(_ s: ToneSettings) -> (amount: Double, sigma: Double, threshold: Double)? { nil }

    /// Auto's suggestion read into white balance, exposure, whites and blacks; every other slider kept.
    /// Stub: returns `s` until TC-5.
    public static func auto(_ a: AutoTone, keeping s: ToneSettings) -> ToneSettings { s }
}
