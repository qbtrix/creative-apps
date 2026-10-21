// ImagingProgram.swift: AdjustSettings compiled to CoreRender's tone steps
// (suite-imaging IM-2 stubs, IM-4 bodies). `adjustments` is the list the CPU
// backend runs one step at a time (export, thumbnails, the histogram);
// `program` is the list one GPU pass runs (`ToneProgram(operations:)`). IM-4
// builds both from one private step list, so they can't drift. Stub: both
// pass `tone` through and add nothing for the settings. Linux-safe.
import CoreRender

public enum ImagingProgram {
    /// The ordered steps: `tone` first (tone-controls' `ToneRules` steps),
    /// then exposure, levels, curve, hue/saturation. Stub: `tone` alone.
    public static func adjustments(_ s: AdjustSettings, tone: [ToneAdjustment] = []) -> [ToneAdjustment] {
        tone
    }

    /// The same steps as GPU program operations. Stub: `tone` alone.
    public static func program(_ s: AdjustSettings, tone: [ToneProgram.Operation] = []) -> [ToneProgram.Operation] {
        tone
    }
}
