// ImagingRoute.swift: which backend runs a list of tone steps (suite-imaging
// IM-2 stub, IM-4 body), and the error the routes throw before their bodies
// land. Stub: `choose` answers `.cpu`, the route every step runs on.
// Linux-safe.
import CoreRender

public enum ImagingRoute: Hashable, Sendable {
    case cpu, gpu

    /// GPU unless the View > Rendering choice says CPU or a step's family is
    /// `notOnMetalYet`. Stub: `.cpu` until IM-4.
    public static func choose(preferGPU: Bool, steps: [ToneAdjustment]) -> ImagingRoute {
        .cpu
    }
}

/// What SuiteImaging throws.
public enum ImagingError: Error, Hashable, Sendable {
    /// The named part has no body yet; the message names the task that fills it.
    case notBuilt(String)
}
