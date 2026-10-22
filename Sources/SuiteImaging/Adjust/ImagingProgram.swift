// ImagingProgram.swift: AdjustSettings compiled to CoreRender's tone steps
// (suite-imaging IM-2 stubs, IM-4 bodies). `adjustments` is the list the CPU
// backend runs one step at a time (export, thumbnails, the histogram);
// `program` is the list one GPU pass runs (`ToneProgram(operations:)`). Both
// come from one private step list, so they can't drift: the GPU list wraps
// each CPU step as `.adjustment`. A neutral part adds no step. Linux-safe.
import CoreRaster
import CoreRender

public enum ImagingProgram {
    /// The ordered steps: `tone` first (tone-controls' `ToneRules` steps),
    /// then exposure, levels, curve, hue/saturation. Neutral settings add none.
    public static func adjustments(_ s: AdjustSettings, tone: [ToneAdjustment] = []) -> [ToneAdjustment] {
        tone + steps(s)
    }

    /// The same steps as GPU program operations, after `tone`.
    public static func program(_ s: AdjustSettings, tone: [ToneProgram.Operation] = []) -> [ToneProgram.Operation] {
        tone + steps(s).map(ToneProgram.Operation.adjustment)
    }

    /// The one step list both backends run: exposure, levels, curve,
    /// hue/saturation, each only when it changes the picture. Levels and the
    /// curve work on sRGB-encoded values, as AdjustSettings stores them.
    private static func steps(_ s: AdjustSettings) -> [ToneAdjustment] {
        var steps: [ToneAdjustment] = []
        if s.exposure != 0 {
            steps.append(.exposure(stops: Float(s.exposure)))
        }
        let l = s.levels
        if l != .neutral {
            steps.append(.levels(inBlack: Float(l.inputBlack), inWhite: Float(l.inputWhite), gamma: Float(l.gamma),
                                 outBlack: Float(l.outputBlack), outWhite: Float(l.outputWhite), encoding: .sRGB))
        }
        let points = s.curve.points
        if !points.allSatisfy({ $0.x == $0.y }) {
            steps.append(.curves(points: points.map { CurvePoint(x: Float($0.x), y: Float($0.y)) }, encoding: .sRGB))
        }
        let hs = s.hueSaturation
        if hs != .neutral {
            steps.append(.hueSaturation(hue: Float(hs.hue), saturation: Float(hs.saturation),
                                        lightness: Float(hs.lightness)))
        }
        return steps
    }
}
