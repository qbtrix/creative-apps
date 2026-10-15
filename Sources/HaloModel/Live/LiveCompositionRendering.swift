// Live/LiveCompositionRendering.swift: the W0 stub of CompositionRendering.
// Planning throws `.notBuilt` and a run fails before writing a frame; the
// render feature (#429) replaces this file whole with the live type.
// Linux-safe.

public struct LiveCompositionRendering: CompositionRendering {
    public init() {}
    public var unavailableHelp: String? { "Render… arrives with #429." }
    public func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        throw HaloEditError.notBuilt("Render")
    }
    public func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, text: (any TextRasterizing)?,
        into sink: inout some RenderSink, isCancelled: () -> Bool
    ) -> HaloRenderOutcome {
        .failed(frame: 0, message: HaloEditError.notBuilt("Render").message)
    }
}
