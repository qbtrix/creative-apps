// ImagingRoute.swift: which backend runs a list of tone steps (suite-imaging
// IM-2 stub, IM-4 body), and the error the routes throw before their bodies
// land. The CPU runs every step; the GPU only the families Metal has, or,
// for a one-pass display write, what core's ToneProgram encodes.
// Linux-safe.
import CoreRender

public enum ImagingRoute: Hashable, Sendable {
    case cpu, gpu

    /// GPU unless the View > Rendering choice says CPU or a step's family is
    /// `notOnMetalYet`.
    public static func choose(preferGPU: Bool, steps: [ToneAdjustment]) -> ImagingRoute {
        guard preferGPU, !steps.contains(where: { RenderOp.notOnMetalYet.contains($0.family) }) else { return .cpu }
        return .gpu
    }

    /// GPU unless the View > Rendering choice says CPU or the display pass
    /// (core's `ToneProgram`, one dispatch per write) has no step for an
    /// operation. Finer than `choose(preferGPU:steps:)`: the program draws the
    /// `.color` family's vibrance and hue/saturation, and a matrix.
    public static func choose(preferGPU: Bool, program: [ToneProgram.Operation]) -> ImagingRoute {
        guard preferGPU, (try? ToneProgram(operations: program)) != nil else { return .cpu }
        return .gpu
    }
}

/// What SuiteImaging throws.
public enum ImagingError: Error, Hashable, Sendable {
    /// The named part has no body yet; the message names the task that fills it.
    case notBuilt(String)
}
