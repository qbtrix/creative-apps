// Fakes/FakeCompositionRendering.swift: a small, predictable
// CompositionRendering (#429): HaloRenderRules with FakeFrameDrawing and
// FakeFrameRendering, so it shares the live plan and frame loop.
// Linux-safe; never used by `.live`.

public struct FakeCompositionRendering: CompositionRendering {
    public init() {}
    public func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        try HaloRenderRules.plan(composition, settings)
    }
    public func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, text: (any TextRasterizing)?,
        into sink: inout some RenderSink, isCancelled: () -> Bool
    ) -> HaloRenderOutcome {
        HaloRenderRules.run(
            plan, of: composition, text: text, drawing: FakeFrameDrawing(), rendering: FakeFrameRendering(),
            into: &sink, isCancelled: isCancelled)
    }
}
